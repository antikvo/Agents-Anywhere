import { http } from '@kit.NetworkKit';
import { apiUrl } from '../core/ServerUrl';
import { HttpClient, HTTP_METHOD_POST, HTTP_METHOD_PATCH } from './HttpClient';
import { SessionSnapshotResponse, TimelineResponse } from './ProtocolDtos';
import { SessionView, SessionsPageResponse } from './SessionDtos';

const DEFAULT_LIMIT: number = 100;

interface AttachmentRefBody {
  fileId: string;
}

interface MetaResponse {
  session: SessionView;
  serverTime?: string;
}

/**
 * 会话列表 API，对齐 Android api/SessionsApi.kt 的 listSessions。
 */
export interface ShareCreateResponse {
  shareId: string;
  sharePath: string;
  shareUrl: string;
  scope: string;
  createdAt: string;
}

interface ShareCreateBody {
  scope: string;
  itemIds: string[];
}

export class SessionsApi {
  private readonly client: HttpClient;

  constructor(client: HttpClient = new HttpClient()) {
    this.client = client;
  }

  async listSessions(serverUrl: string, token: string, archived: boolean,
    limit: number = DEFAULT_LIMIT, cursor?: string): Promise<SessionsPageResponse> {
    let path: string = `/sessions?archived=${archived}&limit=${limit}`;
    if (cursor !== undefined && cursor.length > 0) {
      path = `${path}&cursor=${encodeURIComponent(cursor)}`;
    }
    const text: string = await this.client.requestJson(apiUrl(serverUrl, path), { token: token });
    return JSON.parse(text) as SessionsPageResponse;
  }

  /**
   * 更新会话 meta：标题、置顶、归档。
   */
  async patchMeta(serverUrl: string, token: string, sessionId: string,
    title?: string, pinned?: boolean, archived?: boolean): Promise<SessionView> {
    const path: string = `/sessions/${encodeURIComponent(sessionId)}/meta`;
    const body: Record<string, string | boolean> = {};
    if (title !== undefined) {
      body['title'] = title;
    }
    if (pinned !== undefined) {
      body['pinned'] = pinned;
    }
    if (archived !== undefined) {
      body['archived'] = archived;
    }
    const text: string = await this.client.requestJson(apiUrl(serverUrl, path), {
      method: HTTP_METHOD_PATCH,
      token: token,
      body: JSON.stringify(body)
    });
    const response = JSON.parse(text) as MetaResponse;
    return response.session;
  }

  /**
   * 向前翻页：history 模式按 beforeOrderSeq 取更早的时间线条目。
   */
  async loadTimelineHistory(serverUrl: string, token: string, sessionId: string,
    beforeOrderSeq: number, limit: number = 50): Promise<TimelineResponse> {
    const path: string = `/sessions/${encodeURIComponent(sessionId)}/timeline?mode=history` +
      `&beforeOrderSeq=${beforeOrderSeq}&limit=${limit}`;
    const text: string = await this.client.requestJson(apiUrl(serverUrl, path), { token: token });
    return JSON.parse(text) as TimelineResponse;
  }

  /**
   * 标记已读。服务端要求 body 是裸 JSON 数组。
   */
  async createSessionShare(serverUrl: string, token: string, sessionId: string): Promise<ShareCreateResponse> {
    return await this.createShare(serverUrl, token, sessionId, 'session', []);
  }

  async createMessageShare(serverUrl: string, token: string, sessionId: string,
    itemIds: string[]): Promise<ShareCreateResponse> {
    return await this.createShare(serverUrl, token, sessionId, 'message', itemIds);
  }

  private async createShare(serverUrl: string, token: string, sessionId: string, scope: string,
    itemIds: string[]): Promise<ShareCreateResponse> {
    const path: string = `/sessions/${encodeURIComponent(sessionId)}/shares`;
    const body: ShareCreateBody = { scope: scope, itemIds: itemIds };
    const text: string = await this.client.requestJson(apiUrl(serverUrl, path), {
      method: HTTP_METHOD_POST,
      token: token,
      body: JSON.stringify(body),
      readTimeoutMs: 30000
    });
    return JSON.parse(text) as ShareCreateResponse;
  }

  async markRead(serverUrl: string, token: string, sessionIds: string[]): Promise<void> {
    await this.client.requestJson(apiUrl(serverUrl, '/sessions/read'), {
      method: HTTP_METHOD_POST,
      token: token,
      body: JSON.stringify(sessionIds)
    });
  }

  /**
   * 发送用户消息。离线 Connector 时服务端会返回 409。
   */
  async sendMessage(serverUrl: string, token: string, sessionId: string, content: string,
    clientMessageId: string, fileIds: string[] = []): Promise<void> {
    const path: string = `/sessions/${encodeURIComponent(sessionId)}/runtime/messages`;
    const attachments: AttachmentRefBody[] = [];
    fileIds.forEach((fileId: string) => {
      const ref: AttachmentRefBody = { fileId: fileId };
      attachments.push(ref);
    });
    const payload: string = JSON.stringify({
      content: content,
      attachments: attachments,
      clientMessageId: clientMessageId
    });
    await this.client.requestJson(apiUrl(serverUrl, path), {
      method: HTTP_METHOD_POST,
      token: token,
      body: payload,
      readTimeoutMs: 60000
    });
  }

  /**
   * 首屏快照：会话元信息 + 时间线全量 + 待处理交互。
   */
  async getSnapshot(serverUrl: string, token: string, sessionId: string): Promise<SessionSnapshotResponse> {
    const path: string = `/sessions/${encodeURIComponent(sessionId)}/snapshot`;
    const text: string = await this.client.requestJson(apiUrl(serverUrl, path), {
      token: token,
      readTimeoutMs: 30000
    });
    return JSON.parse(text) as SessionSnapshotResponse;
  }
}
