import { http } from '@kit.NetworkKit';
import { apiUrl } from '../core/ServerUrl';
import { HttpClient, HTTP_METHOD_POST } from './HttpClient';
import { NoticeDto } from './ProtocolDtos';

export interface NoticeListResponse {
  notices: NoticeDto[];
  serverTime: string;
}

interface RespondPayload {
  actionId: string;
  input?: Object;
}

/**
 * Runtime Notice（审批 / 输入请求）接口。
 * 对齐服务端 /sessions/{id}/runtime/notices 与 respond。
 */
export class NoticesApi {
  private readonly client: HttpClient;

  constructor(client: HttpClient = new HttpClient()) {
    this.client = client;
  }

  async list(serverUrl: string, token: string, sessionId: string): Promise<NoticeListResponse> {
    const path: string = `/sessions/${encodeURIComponent(sessionId)}/runtime/notices`;
    const text: string = await this.client.requestJson(apiUrl(serverUrl, path), { token: token });
    return JSON.parse(text) as NoticeListResponse;
  }

  async respond(serverUrl: string, token: string, sessionId: string, noticeId: string,
    actionId: string, input?: Object): Promise<void> {
    const path: string = `/sessions/${encodeURIComponent(sessionId)}/runtime/notices/` +
      `${encodeURIComponent(noticeId)}/respond`;
    const payload: RespondPayload = input === undefined ? { actionId: actionId } :
      { actionId: actionId, input: input };
    await this.client.requestJson(apiUrl(serverUrl, path), {
      method: HTTP_METHOD_POST,
      token: token,
      body: JSON.stringify(payload),
      readTimeoutMs: 30000
    });
  }
}
