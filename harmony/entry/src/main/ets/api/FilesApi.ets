import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
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
interface FsReadResult {
  path: string;
  size: number;
  downloadUrl: string;
  transferId: string;
  token: string;
}

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

  /**
   * 下载文件字节到缓存目录，供图片等原生预览使用。
   */
  async readBytesToCache(serverUrl: string, token: string, connectorId: string, root: string,
    path: string, cacheDir: string): Promise<string> {
    const query: string = `?root=${encodeURIComponent(root)}`;
    const url: string = apiUrl(serverUrl,
      `/connectors/${encodeURIComponent(connectorId)}/fs/read${query}`);
    const request: ReadTextRequest = { path: path };
    const text: string = await this.client.requestJson(url, {
      method: HTTP_METHOD_POST,
      token: token,
      body: JSON.stringify(request)
    });
    const envelope: RpcEnvelope = JSON.parse(text) as RpcEnvelope;
    const result: FsReadResult = envelope.result as FsReadResult;
    const downloadUrl: string = result.downloadUrl.startsWith('http') ?
      result.downloadUrl : `${serverUrl}${result.downloadUrl}`;
    const response = await http.createHttp().request(downloadUrl, {
      method: http.RequestMethod.GET,
      header: { 'Authorization': `Bearer ${token}` },
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      readTimeout: 60000
    });
    if (response.responseCode !== 200) {
      throw new Error(`下载失败（HTTP ${response.responseCode}）`);
    }
    const bytes: ArrayBuffer = response.result as ArrayBuffer;
    const name: string = path.substring(path.lastIndexOf('/') + 1);
    const target: string = `${cacheDir}/${name}`;
    const file = fileIo.openSync(target,
      fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, bytes);
    } finally {
      fileIo.closeSync(file);
    }
    return target;
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
