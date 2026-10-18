import { webSocket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * 极薄的 WebSocket 封装，负责连接、消息透传与有限次重连。
 * 业务语义（补拉、合并）放在 feature 层。
 */
export interface RealtimeCallbacks {
  onOpen: () => void;
  onMessage: (text: string) => void;
  onClose: (reason: string) => void;
  onError: (message: string) => void;
}

const RETRY_DELAY_MS: number = 3000;
const MAX_RETRIES: number = 5;

export class RealtimeClient {
  private socket: webSocket.WebSocket | null = null;
  private callbacks: RealtimeCallbacks | null = null;
  private url: string = '';
  private closedByUser: boolean = false;
  private retryTimer: number = -1;
  private retryCount: number = 0;

  connect(url: string, callbacks: RealtimeCallbacks): void {
    this.disconnect();
    this.url = url;
    this.callbacks = callbacks;
    this.closedByUser = false;
    this.retryCount = 0;
    this.open();
  }

  disconnect(): void {
    this.closedByUser = true;
    if (this.retryTimer !== -1) {
      clearTimeout(this.retryTimer);
      this.retryTimer = -1;
    }
    const socket: webSocket.WebSocket | null = this.socket;
    this.socket = null;
    if (socket !== null) {
      socket.close().catch((error: BusinessError) => {
        // 关闭失败无需处理
      });
    }
  }

  private open(): void {
    const socket: webSocket.WebSocket = webSocket.createWebSocket();
    this.socket = socket;
    socket.on('open', () => {
      this.retryCount = 0;
      const callbacks: RealtimeCallbacks | null = this.callbacks;
      if (callbacks !== null) {
        callbacks.onOpen();
      }
    });
    socket.on('message', (error: BusinessError, value: string | ArrayBuffer) => {
      const callbacks: RealtimeCallbacks | null = this.callbacks;
      if (callbacks === null) {
        return;
      }
      if (typeof value === 'string') {
        callbacks.onMessage(value as string);
      }
    });
    socket.on('close', (error: BusinessError, value: webSocket.CloseResult) => {
      const callbacks: RealtimeCallbacks | null = this.callbacks;
      if (callbacks !== null) {
        callbacks.onClose(value.code !== undefined ? `${value.code}` : 'closed');
      }
      this.scheduleRetry();
    });
    socket.on('error', (error: BusinessError) => {
      const callbacks: RealtimeCallbacks | null = this.callbacks;
      if (callbacks !== null) {
        callbacks.onError(error.message);
      }
      this.scheduleRetry();
    });
    socket.connect(this.url).catch((error: BusinessError) => {
      const callbacks: RealtimeCallbacks | null = this.callbacks;
      if (callbacks !== null) {
        callbacks.onError(error.message);
      }
      this.scheduleRetry();
    });
  }

  private scheduleRetry(): void {
    if (this.closedByUser || this.retryTimer !== -1 || this.retryCount >= MAX_RETRIES) {
      return;
    }
    this.retryCount += 1;
    this.retryTimer = setTimeout(() => {
      this.retryTimer = -1;
      if (!this.closedByUser) {
        this.open();
      }
    }, RETRY_DELAY_MS);
  }
}
