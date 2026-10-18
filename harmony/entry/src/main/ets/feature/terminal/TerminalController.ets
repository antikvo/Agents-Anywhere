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
  private session: AuthSession | null = null;
  private sessionId: string = '';
  buffer: TerminalBuffer = new TerminalBuffer(80, 30);
  onUpdate: () => void = () => {
  };
  onStatus: (text: string) => void = () => {
  };

  getTerminal(): TerminalView | null {
    return this.terminal;
  }

  async start(session: AuthSession, sessionId: string, cols: number, rows: number): Promise<void> {
    this.session = session;
    this.sessionId = sessionId;
    this.buffer.resize(cols, rows);
    this.onStatus('创建中');
    const terminal: TerminalView = await this.api.create(session.serverUrl, session.accessToken,
      sessionId, cols, rows);
    this.terminal = terminal;
    this.buffer.resize(terminal.cols, terminal.rows);
    this.connect(session, sessionId, terminal.terminalId);
    this.onStatus(terminal.status);
  }

  private connect(session: AuthSession, sessionId: string, terminalId: string): void {
    const wsUrl: string = this.streamUrl(session.serverUrl, sessionId, terminalId, session.accessToken);
    const socket: webSocket.WebSocket = webSocket.createWebSocket();
    this.ws = socket;
    socket.on('open', () => {
      this.onStatus('已连接');
      this.sendResize(this.buffer.cols, this.buffer.rows);
    });
    socket.on('message', (err: Object, value: string | ArrayBuffer) => {
      if (typeof value !== 'string') {
        return;
      }
      try {
        const envelope: StreamEnvelope = JSON.parse(value) as StreamEnvelope;
        if (envelope.type === 'output' || envelope.type === 'replay') {
          const data: string | undefined = envelope.data;
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
      this.onStatus('连接已关闭');
    });
    socket.on('error', () => {
      this.onStatus('连接错误');
    });
    socket.connect(wsUrl);
  }

  private streamUrl(serverUrl: string, sessionId: string, terminalId: string, token: string): string {
    let base: string = serverUrl;
    if (base.startsWith('https://')) {
      base = 'wss://' + base.substring(8);
    } else if (base.startsWith('http://')) {
      base = 'ws://' + base.substring(7);
    }
    const path: string = `/api/v2/sessions/${encodeURIComponent(sessionId)}/terminals/` +
      `${encodeURIComponent(terminalId)}/stream?token=${encodeURIComponent(token)}`;
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
