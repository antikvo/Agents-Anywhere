import { webSocket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { TerminalApi, TerminalView } from '../../api/TerminalApi';
import { TerminalBuffer } from '../../model/TerminalBuffer';
import { AuthSession } from '../auth/AuthSessionStore';

interface StreamEnvelope {
  type?: string;
  data?: string;
  seq?: number;
  exitCode?: number;
  message?: string;
}

/**
 * 终端会话：REST 创建 + WebSocket 流（base64 输出、input/resize）。
 * 无在线 Connector 时创建会返回 409，界面展示降级并提供本地演示画面。
 */
export class TerminalController {
  private readonly api: TerminalApi = new TerminalApi();
  private readonly base64: util.Base64Helper = new util.Base64Helper();
  private ws: webSocket.WebSocket | null = null;
  private terminal: TerminalView | null = null;
  private terminals: TerminalView[] = [];
  private session: AuthSession | null = null;
  private sessionId: string = '';
  private buffers: Map<string, TerminalBuffer> = new Map<string, TerminalBuffer>();
  private lastSeq: number = 0;
  private connectToken: number = 0;
  private closedByUser: boolean = true;
  private retryAttempt: number = 0;
  buffer: TerminalBuffer = new TerminalBuffer(80, 30);
  onUpdate: () => void = () => {
  };
  onStatus: (text: string) => void = () => {
  };

  getTerminal(): TerminalView | null {
    return this.terminal;
  }

  getTerminals(): TerminalView[] {
    return this.terminals;
  }

  /**
   * 优先复用会话下已有的 running 终端，没有才新建；随后连接并回放。
   */
  async start(session: AuthSession, sessionId: string, cols: number, rows: number): Promise<void> {
    this.session = session;
    this.sessionId = sessionId;
    this.onStatus('加载终端');
    const existing: TerminalView[] = await this.api.list(session.serverUrl, session.accessToken,
      sessionId);
    this.terminals = existing;
    let terminal: TerminalView | null = null;
    for (let i = 0; i < existing.length; i++) {
      if (existing[i].status === 'running') {
        terminal = existing[i];
        break;
      }
    }
    if (terminal === null) {
      this.onStatus('创建终端');
      terminal = await this.api.create(session.serverUrl, session.accessToken, sessionId, cols, rows);
      this.terminals = this.terminals.concat([terminal]);
    }
    this.switchTo(terminal);
  }

  switchTo(terminal: TerminalView): void {
    const session: AuthSession | null = this.session;
    if (session === null) {
      return;
    }
    this.closedByUser = true;
    this.ws?.close();
    this.ws = null;
    this.terminal = terminal;
    let buffer: TerminalBuffer | undefined = this.buffers.get(terminal.terminalId);
    if (buffer === undefined) {
      buffer = new TerminalBuffer(terminal.cols, terminal.rows);
      this.buffers.set(terminal.terminalId, buffer);
    }
    this.buffer = buffer;
    this.lastSeq = 0;
    this.connect(session, this.sessionId, terminal.terminalId);
    this.onStatus(terminal.status);
  }

  async createAnother(cols: number, rows: number): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null) {
      return;
    }
    this.onStatus('创建终端');
    const terminal: TerminalView = await this.api.create(session.serverUrl, session.accessToken,
      this.sessionId, cols, rows);
    this.terminals = this.terminals.concat([terminal]);
    this.switchTo(terminal);
  }

  reconnect(): void {
    const terminal: TerminalView | null = this.terminal;
    const session: AuthSession | null = this.session;
    if (terminal === null || session === null) {
      return;
    }
    this.closedByUser = true;
    this.ws?.close();
    this.ws = null;
    this.retryAttempt = 0;
    this.onStatus('重连中');
    this.connect(session, this.sessionId, terminal.terminalId);
  }

  private connect(session: AuthSession, sessionId: string, terminalId: string): void {
    this.closedByUser = false;
    this.connectToken++;
    const token: number = this.connectToken;
    const wsUrl: string = this.streamUrl(session.serverUrl, sessionId, terminalId,
      session.accessToken, this.lastSeq);
    const socket: webSocket.WebSocket = webSocket.createWebSocket();
    this.ws = socket;
    socket.on('open', () => {
      if (token !== this.connectToken) {
        return;
      }
      this.retryAttempt = 0;
      this.onStatus('已连接');
      this.sendResize(this.buffer.cols, this.buffer.rows);
    });
    socket.on('message', (err: Object, value: string | ArrayBuffer) => {
      if (token !== this.connectToken || typeof value !== 'string') {
        return;
      }
      try {
        const envelope: StreamEnvelope = JSON.parse(value) as StreamEnvelope;
        if (envelope.type === 'output' || envelope.type === 'replay') {
          const data: string | undefined = envelope.data;
          if (envelope.seq !== undefined && envelope.seq > this.lastSeq) {
            this.lastSeq = envelope.seq;
          }
          if (data !== undefined && data.length > 0) {
            this.buffer.applyBytes(this.base64.decodeSync(data));
            this.onUpdate();
          }
        } else if (envelope.type === 'exit') {
          this.onStatus('已退出');
        } else if (envelope.type === 'error') {
          this.onStatus(envelope.message !== undefined ? envelope.message : '终端错误');
        }
      } catch (error) {
        // 忽略无法解析的帧
      }
    });
    socket.on('close', () => {
      if (token !== this.connectToken || this.closedByUser) {
        this.onStatus('连接已关闭');
        return;
      }
      this.scheduleReconnect(session, sessionId, terminalId);
    });
    socket.on('error', () => {
      if (token !== this.connectToken || this.closedByUser) {
        this.onStatus('连接错误');
      }
    });
    socket.connect(wsUrl);
  }

  private scheduleReconnect(session: AuthSession, sessionId: string, terminalId: string): void {
    if (this.closedByUser) {
      return;
    }
    if (this.retryAttempt >= 6) {
      this.onStatus('连接断开（重连次数已达上限）');
      return;
    }
    this.retryAttempt++;
    const delay: number = Math.min(8000, 500 * Math.pow(2, this.retryAttempt - 1));
    this.onStatus(`连接断开，${Math.round(delay / 1000)}s 后重连 (${this.retryAttempt}/6)`);
    setTimeout(() => {
      if (this.closedByUser) {
        return;
      }
      this.onStatus('重连中…');
      this.connect(session, sessionId, terminalId);
    }, delay);
  }

  private streamUrl(serverUrl: string, sessionId: string, terminalId: string, token: string,
    fromSeq: number = 0): string {
    let base: string = serverUrl;
    if (base.startsWith('https://')) {
      base = 'wss://' + base.substring(8);
    } else if (base.startsWith('http://')) {
      base = 'ws://' + base.substring(7);
    }
    const from: string = fromSeq > 0 ? `&fromSeq=${fromSeq}` : '';
    const path: string = `/api/v2/sessions/${encodeURIComponent(sessionId)}/terminals/` +
      `${encodeURIComponent(terminalId)}/stream?token=${encodeURIComponent(token)}${from}`;
    return base + path;
  }

  sendInput(text: string): void {
    const socket: webSocket.WebSocket | null = this.ws;
    if (socket === null) {
      return;
    }
    const bytes: Uint8Array = new util.TextEncoder().encodeInto(text);
    const data: string = this.base64.encodeToStringSync(bytes);
    socket.send(JSON.stringify({ type: 'input', data: data }));
  }

  sendResize(cols: number, rows: number): void {
    const socket: webSocket.WebSocket | null = this.ws;
    if (socket === null) {
      return;
    }
    socket.send(JSON.stringify({ type: 'resize', cols: cols, rows: rows }));
  }

  async close(): Promise<void> {
    this.closedByUser = true;
    const session: AuthSession | null = this.session;
    const terminal: TerminalView | null = this.terminal;
    this.ws?.close();
    this.ws = null;
    this.terminal = null;
    if (session !== null && terminal !== null) {
      try {
        await this.api.close(session.serverUrl, session.accessToken, this.sessionId,
          terminal.terminalId);
      } catch (error) {
        // 关闭失败不阻塞界面
      }
    }
  }

  /**
   * 离线演示：喂入一段带 ANSI 颜色与光标控制的样例，验证 VT 渲染。
   */
  demo(): void {
    this.buffer.resize(80, 26);
    const script: string = '\u001b[2J\u001b[H' +
      '\u001b[1;32mAgents Anywhere\u001b[0m terminal demo\r\n' +
      '\u001b[36m$\u001b[0m ls -1\r\n' +
      'server/\r\nconnector/\r\nharmony/\r\n' +
      '\u001b[33mwarning:\u001b[0m connector offline, showing local buffer\r\n' +
      '\u001b[1;34m$\u001b[0m echo "hello \u001b[1mVT\u001b[0m"\r\n' +
      'hello VT\r\n' +
      '\u001b[90m-- end of demo --\u001b[0m';
    this.buffer.applyText(script);
    this.onUpdate();
    this.onStatus('演示模式（未连接 Connector）');
  }
}
