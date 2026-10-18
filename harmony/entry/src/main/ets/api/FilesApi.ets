import { apiUrl } from '../core/ServerUrl';
import { HTTP_METHOD_POST, HttpClient } from './HttpClient';

export interface FsEntryDto {
  name: string;
  path: string;
  type: string;
  size?: number | null;
}

export interface FsListResult {
  path: string;
  entries: FsEntryDto[];
  truncated: boolean;
}

interface RpcEnvelope {
  ok: boolean;
  result: Object;
}

interface PreviewTokenResponse {
  previewToken: string;
  expiresAt: string;
}

interface PreviewSessionResponse {
  previewAccessToken: string;
  expiresAt: string;
}

interface ReadTextRequest {
  path: string;
}

interface PreviewTokenRequest {
  previewToken: string;
}

interface PreviewSessionRequest {
  previewAccessToken: string;
  maxBytes: number;
}

interface ReadTextPayload {
  previewAccessToken: string;
  maxBytes: number;
}

export interface FsTextResult {
  path: string;
  name: string;
  size: number;
  encoding: string;
  content: string;
  truncated: boolean;
  binary: boolean;
}

/**
 * 设备文件浏览。Connector 离线时服务端返回 409，调用方展示降级提示。
 * 文本预览走 preview-token → preview-session → preview/readText 三步。
 */
export class FilesApi {
  private readonly client: HttpClient;

  constructor(client: HttpClient = new HttpClient()) {
    this.client = client;
  }

  async list(serverUrl: string, token: string, connectorId: string, root: string,
    path: string): Promise<FsListResult> {
    const query: string = `?root=${encodeURIComponent(root)}`;
    const url: string = apiUrl(serverUrl,
      `/connectors/${encodeURIComponent(connectorId)}/fs/list${query}`);
    const body: ReadTextRequest = { path: path };
    const text: string = await this.client.requestJson(url, {
      method: HTTP_METHOD_POST,
      token: token,
      body: JSON.stringify(body)
    });
    const envelope: RpcEnvelope = JSON.parse(text) as RpcEnvelope;
    return envelope.result as FsListResult;
  }

  async readText(serverUrl: string, token: string, connectorId: string, root: string,
    path: string): Promise<FsTextResult> {
    const query: string = `?root=${encodeURIComponent(root)}`;
    const tokenBase: string = apiUrl(serverUrl,
      `/connectors/${encodeURIComponent(connectorId)}/fs`);
    const sharedBase: string = apiUrl(serverUrl, '/connectors/fs');

    const tokenRequest: ReadTextRequest = { path: path };
    const tokenText: string = await this.client.requestJson(`${tokenBase}/preview-token${query}`, {
      method: HTTP_METHOD_POST,
      token: token,
      body: JSON.stringify(tokenRequest)
    });
    const preview: PreviewTokenResponse = JSON.parse(tokenText) as PreviewTokenResponse;

    const sessionRequest: PreviewTokenRequest = { previewToken: preview.previewToken };
    const sessionText: string = await this.client.requestJson(`${sharedBase}/preview-session`, {
      method: HTTP_METHOD_POST,
      body: JSON.stringify(sessionRequest)
    });
    const session: PreviewSessionResponse = JSON.parse(sessionText) as PreviewSessionResponse;

    const readRequest: PreviewSessionRequest = {
      previewAccessToken: session.previewAccessToken,
      maxBytes: 1048576
    };
    const readText: string = await this.client.requestJson(`${sharedBase}/preview/readText`, {
      method: HTTP_METHOD_POST,
      body: JSON.stringify(readRequest)
    });
    return JSON.parse(readText) as FsTextResult;
  }
}
