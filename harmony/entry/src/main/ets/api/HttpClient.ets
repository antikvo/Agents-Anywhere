import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { RawHttpClient, RawHttpResponse } from './RawHttpClient';

/**
 * 运行时坑：模拟器（HarmonyOS 6.0.1 / API 21）上 http.RequestMethod.PATCH 为 undefined，
 * 直接用枚举会让 PATCH 退化成 GET（body 被拼到 query）。这里用字符串常量兜底。
 */
export const HTTP_METHOD_GET: http.RequestMethod = 'GET' as http.RequestMethod;
export const HTTP_METHOD_POST: http.RequestMethod = 'POST' as http.RequestMethod;
export const HTTP_METHOD_PATCH: http.RequestMethod = 'PATCH' as http.RequestMethod;
export const HTTP_METHOD_DELETE: http.RequestMethod = 'DELETE' as http.RequestMethod;
export const HTTP_METHOD_PUT: http.RequestMethod = 'PUT' as http.RequestMethod;

export enum ApiErrorKind {
  Network = 'network',
  Unauthorized = 'unauthorized',
  Server = 'server',
  Decoding = 'decoding'
}

export class ApiError extends Error {
  readonly kind: ApiErrorKind;
  readonly statusCode: number;

  constructor(kind: ApiErrorKind, message: string, statusCode: number = 0) {
    super(message);
    this.name = 'ApiError';
    this.kind = kind;
    this.statusCode = statusCode;
  }
}

interface ErrorPayload {
  detail?: string;
  message?: string;
}

export interface RequestOptions {
  method?: http.RequestMethod;
  token?: string;
  body?: string | ArrayBuffer;
  contentType?: string;
  connectTimeoutMs?: number;
  readTimeoutMs?: number;
}

export interface HttpResult {
  statusCode: number;
  text: string;
}

/**
 * 极薄的 HTTP 封装，对齐 Android ApiClient 的错误分类。
 * 只依赖 @ohos.net.http，不引入第三方库。
 */
export class HttpClient {
  private readonly connectTimeoutMs: number;
  private readonly readTimeoutMs: number;
  private readonly rawClient: RawHttpClient = new RawHttpClient();

  constructor(connectTimeoutMs: number = 15000, readTimeoutMs: number = 30000) {
    this.connectTimeoutMs = connectTimeoutMs;
    this.readTimeoutMs = readTimeoutMs;
  }

  async request(rawUrl: string, options: RequestOptions = {}): Promise<HttpResult> {
    const rawMethod: string = String(options.method ?? HTTP_METHOD_GET);
    if (rawMethod === 'PATCH' || rawMethod === 'PUT') {
      const body: string = typeof options.body === 'string' ? options.body : '';
      const raw: RawHttpResponse = await this.rawClient.request(rawMethod, rawUrl,
        options.token ?? '', body);
      return { statusCode: raw.statusCode, text: raw.text };
    }
    const request: http.HttpRequest = http.createHttp();
    const headers: Record<string, string> = {
      'Accept': 'application/json'
    };
    if (options.contentType !== undefined) {
      headers['Content-Type'] = options.contentType;
    } else if (typeof options.body === 'string') {
      headers['Content-Type'] = 'application/json';
    }
    if (options.token !== undefined && options.token.length > 0) {
      headers['Authorization'] = 'Bearer ' + options.token;
    }

    const requestOptions: http.HttpRequestOptions = {
      method: options.method ?? HTTP_METHOD_GET,
      header: headers,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: options.connectTimeoutMs ?? this.connectTimeoutMs,
      readTimeout: options.readTimeoutMs ?? this.readTimeoutMs
    };
    if (options.body !== undefined) {
      requestOptions.extraData = options.body;
    }

    try {
      const response: http.HttpResponse = await request.request(rawUrl, requestOptions);
      const text: string = typeof response.result === 'string' ?
        response.result as string : JSON.stringify(response.result);
      return { statusCode: response.responseCode, text: text };
    } catch (error) {
      const businessError = error as BusinessError;
      const methodLabel: string = String(options.method ?? 'GET');
      const detail: string = businessError.message.length > 0 ? businessError.message : 'Could not reach the server.';
      throw new ApiError(
        ApiErrorKind.Network,
        `${detail} [${methodLabel} ${rawUrl.split('/api/v2')[1] ?? ''}]`,
        businessError.code
      );
    } finally {
      request.destroy();
    }
  }

  /**
   * 下载二进制内容（附件、图片）。返回 ArrayBuffer 供 ImageKit 解码。
   */
  async requestBytes(rawUrl: string, options: RequestOptions = {}): Promise<ArrayBuffer> {
    const request: http.HttpRequest = http.createHttp();
    const headers: Record<string, string> = {};
    if (options.token !== undefined && options.token.length > 0) {
      headers['Authorization'] = 'Bearer ' + options.token;
    }
    const requestOptions: http.HttpRequestOptions = {
      method: options.method ?? HTTP_METHOD_GET,
      header: headers,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      connectTimeout: options.connectTimeoutMs ?? this.connectTimeoutMs,
      readTimeout: options.readTimeoutMs ?? this.readTimeoutMs
    };
    try {
      const response: http.HttpResponse = await request.request(rawUrl, requestOptions);
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new ApiError(ApiErrorKind.Server, '附件下载失败', response.responseCode);
      }
      return response.result as ArrayBuffer;
    } catch (error) {
      if (error instanceof ApiError) {
        throw error;
      }
      const businessError = error as BusinessError;
      throw new ApiError(
        ApiErrorKind.Network,
        businessError.message.length > 0 ? businessError.message : 'Could not download attachment.',
        businessError.code
      );
    } finally {
      request.destroy();
    }
  }

  async requestJson(rawUrl: string, options: RequestOptions = {}): Promise<string> {
    const result: HttpResult = await this.request(rawUrl, options);
    if (result.statusCode === 401 || result.statusCode === 403) {
      throw new ApiError(ApiErrorKind.Unauthorized, this.extractMessage(result.text),
        result.statusCode);
    }
    if (result.statusCode < 200 || result.statusCode >= 300) {
      throw new ApiError(ApiErrorKind.Server, this.extractMessage(result.text), result.statusCode);
    }
    return result.text;
  }

  private extractMessage(text: string): string {
    if (text.length === 0) {
      return 'The server returned an empty response.';
    }
    try {
      const parsed: ErrorPayload = JSON.parse(text) as ErrorPayload;
      const detail: string | undefined = parsed.detail;
      const message: string | undefined = parsed.message;
      if (detail !== undefined && detail.length > 0) {
        return detail;
      }
      if (message !== undefined && message.length > 0) {
        return message;
      }
    } catch (error) {
      // 非 JSON 响应，回退到原始文本
    }
    return text;
  }
}
