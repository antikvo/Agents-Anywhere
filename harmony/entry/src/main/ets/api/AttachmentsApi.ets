import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';
import { apiUrl } from '../core/ServerUrl';
import { HTTP_METHOD_POST, HttpClient } from './HttpClient';

interface AttachmentContentResponse {
  fileId: string;
  sessionId: string;
  name: string;
  size: number;
  sha256: string;
  contentBase64: string;
}

export interface UploadedAttachment {
  fileId: string;
  sessionId: string;
  name: string;
  size: number;
  sha256: string;
  mediaType: string;
  createdAt: string;
  downloadUrl: string;
  openUrl: string;
}

interface UploadResponse {
  attachments: UploadedAttachment[];
  serverTime: string;
}

/**
 * 会话附件读取。
 *
 * 服务端下载接口返回 JSON（`contentBase64`），不是二进制流；这里解码后交给 ImageKit。
 * 大文件应考虑改为 `/open` 重定向下载，当前限制在图片预览场景。
 */
export class AttachmentsApi {
  private readonly client: HttpClient;
  private readonly base64: util.Base64Helper = new util.Base64Helper();

  constructor(client: HttpClient = new HttpClient()) {
    this.client = client;
  }

  /**
   * 上传单个文件（multipart/form-data，字段名 files）。
   * 服务端把 blob 暂存，Agent 通过 connector 拉取。
   */
  async upload(serverUrl: string, token: string, sessionId: string, fileName: string,
    mediaType: string, data: ArrayBuffer): Promise<UploadedAttachment> {
    const boundary: string = `----harmony${Date.now()}`;
    const encoder: util.TextEncoder = new util.TextEncoder();
    const head: string = `--${boundary}\r\n` +
      `Content-Disposition: form-data; name="files"; filename="${fileName}"\r\n` +
      `Content-Type: ${mediaType}\r\n\r\n`;
    const tail: string = `\r\n--${boundary}--\r\n`;
    const headBytes: Uint8Array = encoder.encodeInto(head);
    const tailBytes: Uint8Array = encoder.encodeInto(tail);
    const fileBytes: Uint8Array = new Uint8Array(data);
    const body: Uint8Array = new Uint8Array(headBytes.length + fileBytes.length + tailBytes.length);
    body.set(headBytes, 0);
    body.set(fileBytes, headBytes.length);
    body.set(tailBytes, headBytes.length + fileBytes.length);
    const path: string = `/sessions/${encodeURIComponent(sessionId)}/attachments`;
    const result = await this.client.request(apiUrl(serverUrl, path), {
      method: HTTP_METHOD_POST,
      token: token,
      body: body.buffer as ArrayBuffer,
      contentType: `multipart/form-data; boundary=${boundary}`,
      readTimeoutMs: 60000
    });
    const response: UploadResponse = JSON.parse(result.text) as UploadResponse;
    if (response.attachments.length === 0) {
      throw new Error('上传失败：服务端没有返回附件');
    }
    return response.attachments[0];
  }

  async fetchImage(serverUrl: string, token: string, sessionId: string,
    fileId: string): Promise<image.PixelMap> {
    const path: string = `/sessions/${encodeURIComponent(sessionId)}/attachments/` +
      `${encodeURIComponent(fileId)}`;
    const text: string = await this.client.requestJson(apiUrl(serverUrl, path), {
      token: token,
      readTimeoutMs: 30000
    });
    const content: AttachmentContentResponse = JSON.parse(text) as AttachmentContentResponse;
    const bytes: Uint8Array = this.base64.decodeSync(content.contentBase64);
    const source: image.ImageSource = image.createImageSource(bytes.buffer as ArrayBuffer);
    return await source.createPixelMap();
  }
}
