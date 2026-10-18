import { http } from '@kit.NetworkKit';
import { apiUrl } from '../core/ServerUrl';
import { RuntimeStateDto, RuntimeStateResponse } from './ProtocolDtos';
import { SessionView } from './SessionDtos';
import { HttpClient, HTTP_METHOD_POST, HTTP_METHOD_DELETE } from './HttpClient';

interface TakeoverResponse {
  session: SessionView;
}

/**
 * Runtime 控制：接管 / 释放接管 / 打断。
 * takeover 是服务端 DB 操作，离线 Connector 也可切换；打断需要在线 Connector。
 */
export class RuntimeApi {
  private readonly client: HttpClient;

  constructor(client: HttpClient = new HttpClient()) {
    this.client = client;
  }

  async setTakeover(serverUrl: string, token: string, sessionId: string,
    enabled: boolean): Promise<SessionView> {
    const path: string = `/sessions/${encodeURIComponent(sessionId)}/takeover`;
    const text: string = await this.client.requestJson(apiUrl(serverUrl, path), {
      method: enabled ? HTTP_METHOD_POST : HTTP_METHOD_DELETE,
      token: token
    });
    const response: TakeoverResponse = JSON.parse(text) as TakeoverResponse;
    return response.session;
  }

  async getState(serverUrl: string, token: string, sessionId: string): Promise<RuntimeStateDto> {
    const path: string = `/sessions/${encodeURIComponent(sessionId)}/runtime/state`;
    const text: string = await this.client.requestJson(apiUrl(serverUrl, path), { token: token });
    const response: RuntimeStateResponse = JSON.parse(text) as RuntimeStateResponse;
    return response.state;
  }

  async interrupt(serverUrl: string, token: string, sessionId: string): Promise<void> {
    const path: string = `/sessions/${encodeURIComponent(sessionId)}/runtime/interrupt`;
    await this.client.requestJson(apiUrl(serverUrl, path), {
      method: HTTP_METHOD_POST,
      token: token,
      readTimeoutMs: 30000
    });
  }
}
