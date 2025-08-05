#!/usr/bin/env node
import { spawn } from 'node:child_process'
import { readFileSync, existsSync, writeFileSync, mkdirSync, appendFileSync } from 'node:fs'
import { join, resolve, dirname, basename } from 'node:path'
import { fileURLToPath } from 'node:url'
import { Server } from '@modelcontextprotocol/sdk/server/index.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js'
import net from 'node:net'
import os from 'node:os'
import stripAnsi from 'strip-ansi'

// ESモジュール対応
const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

// プロセス管理用のMap
const procs = new Map() // label -> { process, pid, cwd, command, logs, ports, startedAt, health }
const BUFFER_SIZE = 10000 // ログバッファの最大行数
const LOG_DIR = join(os.homedir(), '.devserver-mcp', 'logs')

// ログディレクトリを作成
try {
  mkdirSync(LOG_DIR, { recursive: true })
} catch (error) {
  console.error(`ログディレクトリの作成に失敗: ${error.message}`)
}

// 設定
const CONFIG = {
  allowedCommands: [
    /^pnpm\s+(dev|start|serve)/,
    /^npm\s+run\s+\w+/,
    /^npx\s+convex\s+dev/,
    /^yarn\s+(dev|start|serve)/,
    /^node\s+/,
    /^deno\s+/,
    /^bun\s+/
  ],
  healthCheckInterval: 5000, // 5秒
  authRequired: process.env.DEVSERVER_AUTH === 'true',
  authToken: process.env.DEVSERVER_TOKEN
}

class DevServerMCP {
  constructor() {
    this.server = new Server(
      {
        name: 'devserver-mcp',
        version: '3.0.0'
      },
      {
        capabilities: {
          tools: {}
        }
      }
    )

    this.aliases = new Map() // エイリアス管理
    this.healthCheckers = new Map() // ヘルスチェック管理
    this.setupHandlers()
  }

  // 設定ファイルを読み込む（.devserver.json）
  loadConfig(cwd = process.cwd()) {
    const configPath = join(cwd, '.devserver.json')
    if (!existsSync(configPath)) {
      return null
    }

    try {
      const content = readFileSync(configPath, 'utf-8')
      const config = JSON.parse(content)
      
      // エイリアスも読み込む
      if (config.aliases) {
        Object.entries(config.aliases).forEach(([alias, target]) => {
          this.aliases.set(alias, target)
        })
      }
      
      return config
    } catch (error) {
      console.error(`設定ファイルの読み込みエラー: ${error.message}`)
      return null
    }
  }

  // コマンドの安全性をチェック
  isCommandAllowed(command) {
    return CONFIG.allowedCommands.some(pattern => pattern.test(command))
  }

  // 認証チェック
  checkAuth(args) {
    if (!CONFIG.authRequired) return true
    if (!CONFIG.authToken) return false
    return args.auth === CONFIG.authToken
  }

  // ポートが使用可能かチェック
  async checkPort(port) {
    return new Promise((resolve) => {
      const server = net.createServer()
      server.once('error', () => resolve(false))
      server.once('listening', () => {
        server.close(() => resolve(true))
      })
      server.listen(port)
    })
  }

  // 利用可能なポートを探す
  async findAvailablePort(startPort, maxTries = 10) {
    for (let i = 0; i < maxTries; i++) {
      const port = startPort + i
      if (await this.checkPort(port)) {
        return port
      }
    }
    throw new Error(`利用可能なポートが見つかりません (${startPort}-${startPort + maxTries - 1})`)
  }

  // プロジェクト名を取得
  getProjectName(cwd) {
    return basename(cwd)
  }

  // ラベルからプロセスを検索（エイリアス対応）
  findProcess(label) {
    // エイリアスを解決
    const actualLabel = this.aliases.get(label) || label
    return procs.get(actualLabel)
  }

  // ヘルスチェックを開始
  startHealthCheck(label, port) {
    if (!port) return

    const checkHealth = async () => {
      try {
        const response = await fetch(`http://localhost:${port}/health`)
        const isHealthy = response.ok
        
        const proc = procs.get(label)
        if (proc) {
          proc.health = {
            status: isHealthy ? 'healthy' : 'unhealthy',
            lastCheck: new Date().toISOString()
          }
          
          // 不健全な場合はログに記録
          if (!isHealthy) {
            proc.logs.push({
              time: new Date().toISOString(),
              line: `⚠️ ヘルスチェック失敗: ${response.status}`
            })
          }
        }
      } catch (error) {
        const proc = procs.get(label)
        if (proc) {
          proc.health = {
            status: 'unhealthy',
            lastCheck: new Date().toISOString(),
            error: error.message
          }
        }
      }
    }

    // 定期的にチェック
    const interval = setInterval(checkHealth, CONFIG.healthCheckInterval)
    this.healthCheckers.set(label, interval)
    
    // 初回チェック
    setTimeout(checkHealth, 2000)
  }

  // ヘルスチェックを停止
  stopHealthCheck(label) {
    const interval = this.healthCheckers.get(label)
    if (interval) {
      clearInterval(interval)
      this.healthCheckers.delete(label)
    }
  }

  // ANSIカラーをHTMLに変換（簡易版）
  ansiToHtml(text) {
    const ansiColors = {
      '30': 'black', '31': 'red', '32': 'green', '33': 'yellow',
      '34': 'blue', '35': 'magenta', '36': 'cyan', '37': 'white',
      '90': 'gray', '91': 'lightred', '92': 'lightgreen', '93': 'lightyellow',
      '94': 'lightblue', '95': 'lightmagenta', '96': 'lightcyan', '97': 'white'
    }
    
    // 簡易的な変換（完全ではない）
    return text.replace(/\x1b\[(\d+)m/g, (match, code) => {
      const color = ansiColors[code]
      if (color) return `<span style="color: ${color}">`
      if (code === '0') return '</span>'
      return ''
    })
  }

  // ログをファイルに保存
  saveLog(label, logEntry) {
    const logFile = join(LOG_DIR, `${label}-${new Date().toISOString().split('T')[0]}.jsonl`)
    try {
      appendFileSync(logFile, JSON.stringify(logEntry) + '\n')
    } catch (error) {
      console.error(`ログ保存エラー: ${error.message}`)
    }
  }

  setupHandlers() {
    // ツール一覧を返す
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'up',
          description: '.devserver.json に基づいてすべての開発サーバーを起動します',
          inputSchema: {
            type: 'object',
            properties: {
              cwd: { type: 'string', description: '作業ディレクトリ（省略時は現在のディレクトリ）' },
              auth: { type: 'string', description: '認証トークン（AUTH有効時）' }
            }
          }
        },
        {
          name: 'down',
          description: 'すべての開発サーバーを停止します',
          inputSchema: {
            type: 'object',
            properties: {
              cwd: { type: 'string', description: '作業ディレクトリ（省略時は現在のディレクトリ）' },
              auth: { type: 'string', description: '認証トークン（AUTH有効時）' }
            }
          }
        },
        {
          name: 'groupStart',
          description: 'プロジェクトグループのすべてのサービスを起動します',
          inputSchema: {
            type: 'object',
            properties: {
              project: { type: 'string', description: 'プロジェクト名' },
              auth: { type: 'string', description: '認証トークン' }
            },
            required: ['project']
          }
        },
        {
          name: 'groupStop',
          description: 'プロジェクトグループのすべてのサービスを停止します',
          inputSchema: {
            type: 'object',
            properties: {
              project: { type: 'string', description: 'プロジェクト名' },
              auth: { type: 'string', description: '認証トークン' }
            },
            required: ['project']
          }
        },
        {
          name: 'start',
          description: '開発サーバーを起動します',
          inputSchema: {
            type: 'object',
            properties: {
              cwd: { type: 'string', description: '作業ディレクトリ（省略時は現在のディレクトリ）' },
              command: { type: 'string', description: '実行コマンド', default: 'pnpm dev' },
              label: { type: 'string', description: 'プロセスのラベル（例: next, convex）' },
              auth: { type: 'string', description: '認証トークン' }
            },
            required: ['label']
          }
        },
        {
          name: 'stop',
          description: '開発サーバーを停止します',
          inputSchema: {
            type: 'object',
            properties: {
              label: { type: 'string', description: 'プロセスのラベルまたはエイリアス' },
              auth: { type: 'string', description: '認証トークン' }
            },
            required: ['label']
          }
        },
        {
          name: 'restart',
          description: '開発サーバーを再起動します',
          inputSchema: {
            type: 'object',
            properties: {
              cwd: { type: 'string', description: '作業ディレクトリ（省略時は現在のディレクトリ）' },
              command: { type: 'string', description: '実行コマンド', default: 'pnpm dev' },
              label: { type: 'string', description: 'プロセスのラベル' },
              auth: { type: 'string', description: '認証トークン' }
            },
            required: ['label']
          }
        },
        {
          name: 'logs',
          description: '開発サーバーのログを取得します',
          inputSchema: {
            type: 'object',
            properties: {
              label: { type: 'string', description: 'プロセスのラベルまたはエイリアス' },
              lines: { type: 'integer', description: '取得する行数', default: 200 },
              grep: { type: 'string', description: 'フィルタパターン（正規表現）' },
              stream: { type: 'boolean', description: 'ストリーミングモード' },
              color: { type: 'boolean', description: 'ANSIカラーを保持', default: false }
            },
            required: ['label']
          }
        },
        {
          name: 'status',
          description: 'すべての開発サーバーの状態を確認します',
          inputSchema: {
            type: 'object',
            properties: {
              project: { type: 'string', description: 'プロジェクトでフィルタ' }
            }
          }
        }
      ]
    }))

    // ツール実行を処理
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params

      // 認証チェック
      if (!this.checkAuth(args)) {
        return {
          content: [{ type: 'text', text: '❌ 認証エラー: 有効なトークンが必要です' }],
          isError: true
        }
      }

      try {
        switch (name) {
          case 'up':
            return this.up(args)
          case 'down':
            return this.down(args)
          case 'groupStart':
            return this.groupStart(args)
          case 'groupStop':
            return this.groupStop(args)
          case 'start':
            return this.start(args)
          case 'stop':
            return this.stop(args)
          case 'restart':
            return this.restart(args)
          case 'logs':
            return this.logs(args)
          case 'status':
            return this.status(args)
          default:
            return {
              content: [{ type: 'text', text: `未知のツール: ${name}` }]
            }
        }
      } catch (error) {
        return {
          content: [{ type: 'text', text: `エラー: ${error.message}` }],
          isError: true
        }
      }
    })
  }

  // 一括起動
  async up(args) {
    const cwd = resolve(args.cwd || process.cwd())
    const config = this.loadConfig(cwd)

    if (!config || !config.services) {
      return {
        content: [{
          type: 'text',
          text: '❌ .devserver.json が見つかりません\n\n以下の内容で .devserver.json を作成してください:\n\n' +
                '```json\n' +
                '{\n' +
                '  "services": [\n' +
                '    { "label": "next", "command": "pnpm dev", "port": 3000 },\n' +
                '    { "label": "convex", "command": "npx convex dev", "cloudPort": 3210, "sitePort": 6810 }\n' +
                '  ],\n' +
                '  "aliases": {\n' +
                '    "web": "next",\n' +
                '    "api": "convex"\n' +
                '  }\n' +
                '}\n' +
                '```'
        }]
      }
    }

    const projectName = this.getProjectName(cwd)
    const results = []
    
    for (const service of config.services) {
      try {
        const result = await this.startService(cwd, service, projectName)
        results.push(result)
      } catch (error) {
        results.push(`❌ ${service.label}: ${error.message}`)
      }
    }

    return {
      content: [{
        type: 'text',
        text: `🚀 開発サーバーの一括起動:\n\n${results.join('\n')}`
      }]
    }
  }

  // サービスを起動（内部メソッド）
  async startService(cwd, service, projectName) {
    let command = service.command
    const label = projectName ? `${projectName}:${service.label}` : service.label
    const ports = {}

    // コマンドの安全性チェック
    if (!this.isCommandAllowed(command)) {
      throw new Error(`許可されていないコマンド: ${command}`)
    }

    // ポート自動割り当て
    if (service.port) {
      const availablePort = await this.findAvailablePort(service.port)
      ports.main = availablePort
      if (availablePort !== service.port) {
        command = `PORT=${availablePort} ${command}`
      }
    }

    // Convexのポート設定
    if (service.cloudPort && service.sitePort) {
      const cloudPort = await this.findAvailablePort(service.cloudPort)
      const sitePort = await this.findAvailablePort(service.sitePort)
      ports.cloud = cloudPort
      ports.site = sitePort
      
      // Convexコマンドにポートオプションを追加
      if (command.includes('convex dev')) {
        command += ` --local --local-cloud-port ${cloudPort} --local-site-port ${sitePort}`
      }
    }

    await this.start({
      cwd,
      command,
      label,
      ports,
      healthEndpoint: service.healthEndpoint
    })

    const portInfo = Object.entries(ports)
      .map(([key, port]) => `${key}: ${port}`)
      .join(', ')

    return `✅ ${label} を起動しました${portInfo ? ` (${portInfo})` : ''}`
  }

  // グループ起動
  async groupStart(args) {
    const { project } = args
    const results = []

    // すべてのプロセスから指定プロジェクトのものを探す
    for (const [label, proc] of procs.entries()) {
      if (label.startsWith(`${project}:`)) {
        results.push(`すでに起動中: ${label}`)
      }
    }

    // プロジェクトディレクトリを探す（簡易実装）
    const projectDirs = [
      join(process.cwd(), project),
      join(process.cwd(), '..', project),
      join(os.homedir(), 'Work', project),
      join(os.homedir(), 'Projects', project)
    ]

    for (const dir of projectDirs) {
      if (existsSync(dir)) {
        const result = await this.up({ cwd: dir })
        return result
      }
    }

    return {
      content: [{
        type: 'text',
        text: `❌ プロジェクト ${project} が見つかりません`
      }]
    }
  }

  // グループ停止
  async groupStop(args) {
    const { project } = args
    const results = []

    for (const [label, proc] of procs.entries()) {
      if (label.startsWith(`${project}:`)) {
        try {
          await this.stop({ label })
          results.push(`✅ ${label} を停止しました`)
        } catch (error) {
          results.push(`❌ ${label}: ${error.message}`)
        }
      }
    }

    if (results.length === 0) {
      return {
        content: [{
          type: 'text',
          text: `プロジェクト ${project} のプロセスは起動していません`
        }]
      }
    }

    return {
      content: [{
        type: 'text',
        text: `🛑 ${project} の停止:\n\n${results.join('\n')}`
      }]
    }
  }

  // 一括停止
  async down(args) {
    const cwd = resolve(args.cwd || process.cwd())
    const config = this.loadConfig(cwd)
    const projectName = this.getProjectName(cwd)
    
    const results = []
    
    if (config && config.services) {
      // 設定ファイルのサービスを停止
      for (const service of config.services) {
        const label = projectName ? `${projectName}:${service.label}` : service.label
        if (procs.has(label)) {
          try {
            await this.stop({ label })
            results.push(`✅ ${label} を停止しました`)
          } catch (error) {
            results.push(`❌ ${label}: ${error.message}`)
          }
        }
      }
    } else {
      // 設定ファイルがない場合は、現在のディレクトリで起動したすべてのプロセスを停止
      for (const [label, proc] of procs.entries()) {
        if (proc.cwd === cwd) {
          try {
            await this.stop({ label })
            results.push(`✅ ${label} を停止しました`)
          } catch (error) {
            results.push(`❌ ${label}: ${error.message}`)
          }
        }
      }
    }

    if (results.length === 0) {
      return {
        content: [{
          type: 'text',
          text: '停止するプロセスがありません'
        }]
      }
    }

    return {
      content: [{
        type: 'text',
        text: `🛑 開発サーバーの一括停止:\n\n${results.join('\n')}`
      }]
    }
  }

  async start(args) {
    const cwd = resolve(args.cwd || process.cwd())
    const { command = 'pnpm dev', label, ports = {}, healthEndpoint } = args

    if (procs.has(label)) {
      throw new Error(`${label} は既に起動中です`)
    }

    // コマンドの安全性チェック
    if (!this.isCommandAllowed(command)) {
      throw new Error(`許可されていないコマンド: ${command}`)
    }

    // プロセスが異常終了した場合の自動再起動フラグ
    const autoRestart = args.autoRestart !== false

    const startProcess = async () => {
      const [cmd, ...cmdArgs] = command.split(' ')
      const child = spawn(cmd, cmdArgs, {
        cwd,
        shell: true,
        env: { ...process.env },
        stdio: ['ignore', 'pipe', 'pipe'],
        detached: true  // プロセスグループのリーダーにする
      })

      // ログバッファを初期化
      const logs = []
      
      // stdout/stderrを捕捉
      const captureOutput = (data) => {
        const lines = data.toString().split('\n').filter(l => l.trim())
        lines.forEach(line => {
          const logEntry = {
            time: new Date().toISOString(),
            line,
            label,
            pid: child.pid
          }
          logs.push(logEntry)
          
          // ログをファイルに保存
          this.saveLog(label, logEntry)
          
          // バッファサイズを超えたら古いログを削除
          if (logs.length > BUFFER_SIZE) {
            logs.splice(0, logs.length - BUFFER_SIZE)
          }
        })
      }

      child.stdout.on('data', captureOutput)
      child.stderr.on('data', captureOutput)

      child.on('error', (error) => {
        const logEntry = {
          time: new Date().toISOString(),
          line: `エラー: ${error.message}`,
          label,
          pid: child.pid,
          error: true
        }
        logs.push(logEntry)
        this.saveLog(label, logEntry)
      })

      child.on('exit', (code, signal) => {
        const logEntry = {
          time: new Date().toISOString(),
          line: `プロセスが終了しました (code: ${code}, signal: ${signal})`,
          label,
          pid: child.pid,
          exit: { code, signal }
        }
        logs.push(logEntry)
        this.saveLog(label, logEntry)
        
        // ヘルスチェックを停止
        this.stopHealthCheck(label)
        
        const proc = procs.get(label)
        if (proc && proc.autoRestart && code !== 0 && signal !== 'SIGTERM' && signal !== 'SIGKILL') {
          // 異常終了の場合、3秒後に自動再起動
          console.error(`${label} が異常終了しました。3秒後に再起動します...`)
          setTimeout(() => {
            if (procs.has(label)) {
              procs.delete(label)
              startProcess()
            }
          }, 3000)
        } else {
          procs.delete(label)
        }
      })

      procs.set(label, {
        process: child,
        pid: child.pid,
        cwd,
        command,
        logs,
        ports,
        autoRestart,
        startedAt: new Date().toISOString(),
        health: { status: 'starting' }
      })

      // ヘルスチェックを開始
      if (ports.main || healthEndpoint) {
        this.startHealthCheck(label, ports.main || 3000)
      }

      return child.pid
    }

    const pid = await startProcess()

    // ポート情報を含むレスポンス
    const response = {
      ok: true,
      pid,
      label,
      ports
    }

    // ポート変更があった場合の追加情報
    if (args.originalPort && ports.main !== args.originalPort) {
      response.portChanged = true
      response.originalPort = args.originalPort
    }

    return {
      content: [{
        type: 'text',
        text: `✅ ${label} を起動しました\nPID: ${pid}\nコマンド: ${command}\nディレクトリ: ${cwd}${autoRestart ? '\n自動再起動: 有効' : ''}${ports.main ? `\nポート: ${ports.main}` : ''}`
      }]
    }
  }

  async stop(args) {
    const { label } = args
    const proc = this.findProcess(label)

    if (!proc) {
      throw new Error(`${label} は起動していません`)
    }

    // 実際のラベルを取得
    const actualLabel = this.aliases.get(label) || label

    // ヘルスチェックを停止
    this.stopHealthCheck(actualLabel)

    // 自動再起動を無効化
    proc.autoRestart = false

    // Convex固有の処理
    if (proc.command.includes('convex')) {
      try {
        // convex-local-backendプロセスも停止
        const { exec } = await import('node:child_process')
        await new Promise((resolve) => {
          exec('pkill -f convex-local-backend', (error) => {
            // エラーは無視（プロセスが存在しない場合もあるため）
            resolve()
          })
        })
      } catch (error) {
        // エラーログ（デバッグ用）
        console.error('Convex cleanup error:', error)
      }
    }

    // プロセスグループ全体にSIGTERMを送信
    try {
      // 負のPIDを使用してプロセスグループ全体にシグナルを送信
      process.kill(-proc.process.pid, 'SIGTERM')
    } catch (error) {
      // プロセスグループが存在しない場合は通常の方法で終了
      proc.process.kill('SIGTERM')
    }
    
    // 強制終了用のタイマー（5秒後）
    setTimeout(() => {
      if (procs.has(actualLabel)) {
        try {
          process.kill(-proc.process.pid, 'SIGKILL')
        } catch (error) {
          proc.process.kill('SIGKILL')
        }
        procs.delete(actualLabel)
      }
    }, 5000)

    return {
      content: [{
        type: 'text',
        text: `✅ ${actualLabel} を停止しました\nPID: ${proc.pid}`
      }]
    }
  }

  async restart(args) {
    const cwd = resolve(args.cwd || process.cwd())
    const { label } = args
    const proc = this.findProcess(label)
    
    // 既存のプロセスがあれば停止
    if (proc) {
      const actualLabel = this.aliases.get(label) || label
      this.stop({ label })
      
      // 停止を待つ
      return new Promise((resolve) => {
        setTimeout(async () => {
          // 既存のコマンドとcwdを使用
          const result = await this.start({
            cwd: args.cwd || proc.cwd,
            command: args.command || proc.command,
            label: actualLabel,
            ports: proc.ports,
            autoRestart: args.autoRestart
          })
          resolve(result)
        }, 1000)
      })
    } else {
      // なければ新規起動
      return this.start({ ...args, cwd })
    }
  }

  logs(args) {
    const { label, lines = 200, grep, stream = false, color = false } = args
    const proc = this.findProcess(label)

    if (!proc) {
      throw new Error(`${label} は起動していません`)
    }

    // 最新のログを指定行数分取得
    let recentLogs = proc.logs.slice(-lines)
    
    // grepフィルタを適用
    if (grep) {
      try {
        const pattern = new RegExp(grep, 'i')
        recentLogs = recentLogs.filter(log => pattern.test(log.line))
      } catch (error) {
        return {
          content: [{
            type: 'text',
            text: `❌ 無効な正規表現: ${grep}`
          }]
        }
      }
    }
    
    if (recentLogs.length === 0) {
      return {
        content: [{
          type: 'text',
          text: `${label} のログ${grep ? ` (フィルタ: ${grep})` : ''}はありません`
        }]
      }
    }

    // ストリーミングモードの場合はメタデータを追加
    if (stream) {
      return {
        content: [{
          type: 'text',
          text: `📡 ${label} のログストリーム開始（未実装）`
        }]
      }
    }

    // ログフォーマット
    const logText = recentLogs
      .map(log => {
        const time = new Date(log.time).toLocaleTimeString('ja-JP')
        const line = color ? log.line : stripAnsi(log.line)
        return `[${time}] ${line}`
      })
      .join('\n')

    // カラー対応の場合はHTMLでラップ
    const formattedLog = color ? 
      `<pre>${this.ansiToHtml(logText)}</pre>` : 
      logText

    return {
      content: [{
        type: 'text',
        text: `📋 ${label} のログ (${recentLogs.length} 行${grep ? `, フィルタ: ${grep}` : ''}):\n\n${formattedLog}`
      }]
    }
  }

  status(args) {
    const { project } = args || {}
    let processes = Array.from(procs.entries())

    // プロジェクトでフィルタ
    if (project) {
      processes = processes.filter(([label]) => label.startsWith(`${project}:`))
    }

    if (processes.length === 0) {
      return {
        content: [{
          type: 'text',
          text: project ? 
            `プロジェクト ${project} のプロセスはありません` :
            '現在起動中のプロセスはありません'
        }]
      }
    }

    const statusLines = processes.map(([label, proc]) => {
      const uptime = new Date() - new Date(proc.startedAt)
      const uptimeStr = this.formatUptime(uptime)
      
      // ポート情報
      const portInfo = proc.ports && Object.keys(proc.ports).length > 0 ?
        `\n  ポート: ${Object.entries(proc.ports).map(([k, v]) => `${k}=${v}`).join(', ')}` :
        ''
      
      // ヘルス情報
      const healthInfo = proc.health ?
        `\n  ヘルス: ${proc.health.status}` :
        ''
      
      // エイリアス情報
      const aliasInfo = Array.from(this.aliases.entries())
        .filter(([alias, target]) => target === label)
        .map(([alias]) => alias)
      const aliasStr = aliasInfo.length > 0 ?
        ` (エイリアス: ${aliasInfo.join(', ')})` :
        ''

      return `• ${label}${aliasStr}: PID ${proc.pid}, 稼働時間 ${uptimeStr}${proc.autoRestart ? ' 🔄' : ''}\n  コマンド: ${proc.command}\n  ディレクトリ: ${proc.cwd}${portInfo}${healthInfo}`
    })

    return {
      content: [{
        type: 'text',
        text: `📊 起動中のプロセス:\n\n${statusLines.join('\n\n')}`
      }]
    }
  }

  formatUptime(ms) {
    const seconds = Math.floor(ms / 1000)
    const minutes = Math.floor(seconds / 60)
    const hours = Math.floor(minutes / 60)
    const days = Math.floor(hours / 24)

    if (days > 0) return `${days}日 ${hours % 24}時間`
    if (hours > 0) return `${hours}時間 ${minutes % 60}分`
    if (minutes > 0) return `${minutes}分 ${seconds % 60}秒`
    return `${seconds}秒`
  }

  async run() {
    const transport = new StdioServerTransport()
    await this.server.connect(transport)
    console.error('DevServer MCP v3.0.0 が起動しました')
    
    // 設定情報を表示
    if (CONFIG.authRequired) {
      console.error('認証: 有効')
    }
    console.error(`ログディレクトリ: ${LOG_DIR}`)
  }
}

// クリーンアップ処理
process.on('SIGINT', () => {
  console.error('シャットダウン中...')
  
  // ヘルスチェックを停止
  const mcp = new DevServerMCP()
  for (const [label] of procs.entries()) {
    mcp.stopHealthCheck(label)
  }
  
  // プロセスを停止
  for (const [label, proc] of procs.entries()) {
    console.error(`${label} を停止中...`)
    proc.process.kill('SIGTERM')
  }
  
  process.exit(0)
})

// サーバー起動
const app = new DevServerMCP()
app.run().catch(console.error)