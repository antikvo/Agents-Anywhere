import { apiUrl } from '../core/ServerUrl';
import { HTTP_METHOD_POST, HTTP_METHOD_DELETE, HttpClient } from './HttpClient';

export interface TerminalView {
  terminalId: string;
  sessionId: string;
  label: string;
  root: string;
  cwd: string;
  cols: number;
  rows: number;
  status: string;
  exitCode?: number | null;
  createdAt: string;
}

interface TerminalResponse {
  terminal: TerminalView;
  serverTime: string;
}

interface TerminalCreateRequest {
  cols: number;
  rows: number;
  label: string;
}

export class TerminalApi {
  private readonly client: HttpClient;

  constructor(client: HttpClient = new HttpClient()) {
    this.client = client;
  }

  async create(serverUrl: string, token: string, sessionId: string, cols: number,
    rows: number): Promise<TerminalView> {
    const path: string = `/sessions/${encodeURIComponent(sessionId)}/terminals`;
    const payload: TerminalCreateRequest = { cols: cols, rows: rows, label: 'Harmony' };
    const text: string = await this.client.requestJson(apiUrl(serverUrl, path), {
      method: HTTP_METHOD_POST,
      token: token,
      body: JSON.stringify(payload),
      readTimeoutMs: 30000
    });
    const response: TerminalResponse = JSON.parse(text) as TerminalResponse;
    return response.terminal;
  }

  async close(serverUrl: string, token: string, sessionId: string, terminalId: string): Promise<void> {
    const path: string = `/sessions/${encodeURIComponent(sessionId)}/terminals/` +
      `${encodeURIComponent(terminalId)}`;
    await this.client.requestJson(apiUrl(serverUrl, path), {
      method: HTTP_METHOD_DELETE,
      token: token
    });
  }
}
