import { EventEnvelope, EventRecoveryResponse, RealtimeApi } from '../../api/RealtimeApi';
import { NoticesApi } from '../../api/NoticesApi';
import { RuntimeApi } from '../../api/RuntimeApi';
import { RealtimeClient } from '../../api/RealtimeClient';
import { NoticeDto, RuntimeStateDto, SessionSnapshotResponse, TimelineItemDto } from '../../api/ProtocolDtos';
import { SessionView } from '../../api/SessionDtos';
import { AttachmentsApi, UploadedAttachment } from '../../api/AttachmentsApi';
import { SessionsApi, ShareCreateResponse } from '../../api/SessionsApi';
import { CommandsApi, RuntimeCommand } from '../../api/CommandsApi';
import { AuthSession } from '../auth/AuthSessionStore';
import { TimelineRow, toTimelineRows } from '../../model/Timeline';

export interface SessionDetailResult {
  session: SessionView;
  rows: TimelineRow[];
  notices: NoticeDto[];
  hasMore: boolean;
  nextSeq: number;
}

export enum RealtimeState {
  Connecting = 'connecting',
  Connected = 'connected',
  Disconnected = 'disconnected'
}

interface ItemPayload {
  item?: TimelineItemDto | null;
}

interface SnapshotPayload {
  items?: TimelineItemDto[] | null;
}

interface SubscribedPayload {
  eventCursor?: string | null;
}

interface SessionMetaPayload {
  session?: SessionView | null;
}

interface NoticePayload {
  notice?: NoticeDto | null;
}

interface NoticeSnapshotPayload {
  notices?: NoticeDto[] | null;
}

/**
 * 会话详情：快照 + WS 增量 + 断线补拉。
 *
 * 合并规则对齐 Android：
 * - timeline.snapshot 是全量替换；
 * - timeline.item_created / item_updated 按 id upsert；
 * - 其他事件类型首版忽略。
 */
export class SessionDetailController {
  private readonly sessionsApi: SessionsApi;
  private readonly realtimeApi: RealtimeApi;
  private readonly realtime: RealtimeClient;
  private readonly items: Map<string, TimelineItemDto> = new Map<string, TimelineItemDto>();
  private readonly notices: Map<string, NoticeDto> = new Map<string, NoticeDto>();
  private readonly clientId: string = `harmony-${Date.now()}`;
  private cursor: string = 'seq:0';
  private runtimeState: RuntimeStateDto | null = null;
  private readonly attachmentsApi: AttachmentsApi = new AttachmentsApi();
  private pendingAttachments: UploadedAttachment[] = [];
  private hasMore: boolean = false;
  private oldestOrderSeq: number = 0;
  private loadingOlder: boolean = false;
  private currentSession: AuthSession | null = null;
  private currentSessionId: string = '';
  private connectorId: string = '';
  private runtimeId: string = '';
  private readonly commandsApi: CommandsApi = new CommandsApi();

  onRows: (rows: TimelineRow[]) => void = () => {
  };
  onState: (state: RealtimeState, detail: string) => void = () => {
  };
  onSessionMeta: (session: SessionView) => void = () => {
  };
  onNotices: (notices: NoticeDto[]) => void = () => {
  };

  private readonly noticesApi: NoticesApi;
  private readonly runtimeApi: RuntimeApi;

  constructor(sessionsApi: SessionsApi = new SessionsApi(),
    realtimeApi: RealtimeApi = new RealtimeApi(),
    realtime: RealtimeClient = new RealtimeClient(),
    noticesApi: NoticesApi = new NoticesApi(),
    runtimeApi: RuntimeApi = new RuntimeApi()) {
    this.sessionsApi = sessionsApi;
    this.realtimeApi = realtimeApi;
    this.realtime = realtime;
    this.noticesApi = noticesApi;
    this.runtimeApi = runtimeApi;
  }

  async load(session: AuthSession, sessionId: string): Promise<SessionDetailResult> {
    this.currentSession = session;
    this.currentSessionId = sessionId;
    const snapshot: SessionSnapshotResponse =
      await this.sessionsApi.getSnapshot(session.serverUrl, session.accessToken, sessionId);
    this.items.clear();
    snapshot.timeline.items.forEach((item: TimelineItemDto) => {
      this.items.set(item.id, item);
    });
    this.connectorId = snapshot.session.connectorId;
    const snapshotRuntimeId: string | null | undefined = snapshot.session.runtimeId;
    this.runtimeId = snapshotRuntimeId === undefined || snapshotRuntimeId === null ? '' : snapshotRuntimeId;
    this.cursor = snapshot.eventCursor.length > 0 ? snapshot.eventCursor : 'seq:0';
    this.notices.clear();
    const snapshotNotices: NoticeDto[] | null | undefined = snapshot.notices;
    if (snapshotNotices !== undefined && snapshotNotices !== null) {
      snapshotNotices.forEach((notice: NoticeDto) => {
        this.notices.set(notice.noticeId, notice);
      });
    }
    this.onNotices(this.openNotices());
    this.runtimeState = snapshot.state === undefined || snapshot.state === null ? null : snapshot.state;
    this.hasMore = snapshot.timeline.hasMore;
    this.oldestOrderSeq = this.minOrderSeq();
    this.markRead();
    return {
      session: snapshot.session,
      rows: this.rows(),
      notices: this.openNotices(),
      hasMore: snapshot.timeline.hasMore,
      nextSeq: snapshot.timeline.nextSeq
    };
  }

  async rename(session: AuthSession, sessionId: string, title: string): Promise<string> {
    const view: SessionView = await this.sessionsApi.patchMeta(session.serverUrl,
      session.accessToken, sessionId, title, undefined, undefined);
    return view.title === undefined || view.title === null ? title : view.title;
  }

  async createShare(session: AuthSession, sessionId: string): Promise<string> {
    const share: ShareCreateResponse = await this.sessionsApi.createSessionShare(session.serverUrl,
      session.accessToken, sessionId);
    return share.shareUrl;
  }

  async createMessageShare(session: AuthSession, sessionId: string, itemIds: string[]): Promise<string> {
    const share: ShareCreateResponse = await this.sessionsApi.createMessageShare(session.serverUrl,
      session.accessToken, sessionId, itemIds);
    return share.shareUrl;
  }

  async commands(session: AuthSession): Promise<RuntimeCommand[]> {
    return await this.commandsApi.list(session.serverUrl, session.accessToken, this.connectorId,
      this.runtimeId);
  }

  async connect(): Promise<void> {
    const session: AuthSession | null = this.currentSession;
    const sessionId: string = this.currentSessionId;
    if (session === null || sessionId.length === 0) {
      return;
    }
    this.onState(RealtimeState.Connecting, '正在连接');
    try {
      const ticket = await this.realtimeApi.createSessionTicket(session.serverUrl, session.accessToken,
        this.clientId, sessionId);
      const url: string = this.realtimeApi.sessionSocketUrl(session.serverUrl, sessionId, ticket.ticket);
      this.realtime.connect(url, {
        onOpen: () => {
          this.onState(RealtimeState.Connected, '实时');
          this.catchUp();
        },
        onMessage: (text: string) => {
          this.handleMessage(text);
        },
        onClose: (reason: string) => {
          this.onState(RealtimeState.Disconnected, '离线');
        },
        onError: (message: string) => {
          this.onState(RealtimeState.Disconnected, '离线');
        }
      });
    } catch (error) {
      this.onState(RealtimeState.Disconnected, '离线');
    }
  }

  disconnect(): void {
    this.realtime.disconnect();
  }

  private handleMessage(text: string): void {
    let parsed: EventEnvelope;
    try {
      parsed = JSON.parse(text) as EventEnvelope;
    } catch (error) {
      return;
    }
    if (parsed.type === 'keepalive') {
      return;
    }
    if (parsed.cursor !== undefined && parsed.cursor.length > 0) {
      this.cursor = parsed.cursor;
    }
    if (this.applyEvent(parsed)) {
      this.onRows(this.rows());
    }
  }

  private applyEvent(envelope: EventEnvelope): boolean {
    if (envelope.type === 'timeline.item_created' || envelope.type === 'timeline.item_updated') {
      const payload: ItemPayload = envelope.payload as ItemPayload;
      const item: TimelineItemDto | null | undefined = payload.item;
      if (item === undefined || item === null) {
        return false;
      }
      this.items.set(item.id, item);
      return true;
    }
    if (envelope.type === 'timeline.snapshot') {
      const payload: SnapshotPayload = envelope.payload as SnapshotPayload;
      const items: TimelineItemDto[] | null | undefined = payload.items;
      if (items === undefined || items === null) {
        return false;
      }
      this.items.clear();
      items.forEach((item: TimelineItemDto) => {
        this.items.set(item.id, item);
      });
      return true;
    }
    if (envelope.type === 'session.subscribed') {
      const payload: SubscribedPayload = envelope.payload as SubscribedPayload;
      const cursor: string | null | undefined = payload.eventCursor;
      if (cursor !== undefined && cursor !== null && cursor.length > 0) {
        this.cursor = cursor;
      }
      return false;
    }
    if (envelope.type === 'runtime.notice.updated') {
      const payload: NoticePayload = envelope.payload as NoticePayload;
      const notice: NoticeDto | null | undefined = payload.notice;
      if (notice === undefined || notice === null) {
        return false;
      }
      this.notices.set(notice.noticeId, notice);
      this.onNotices(this.openNotices());
      return false;
    }
    if (envelope.type === 'runtime.notice.snapshot') {
      const payload: NoticeSnapshotPayload = envelope.payload as NoticeSnapshotPayload;
      const notices: NoticeDto[] | null | undefined = payload.notices;
      if (notices === undefined || notices === null) {
        return false;
      }
      this.notices.clear();
      notices.forEach((notice: NoticeDto) => {
        this.notices.set(notice.noticeId, notice);
      });
      this.onNotices(this.openNotices());
      return false;
    }
    if (envelope.type === 'session.meta.updated') {
      const payload: SessionMetaPayload = envelope.payload as SessionMetaPayload;
      const session: SessionView | null | undefined = payload.session;
      if (session !== undefined && session !== null) {
        this.onSessionMeta(session);
      }
      return false;
    }
    return false;
  }

  private async catchUp(): Promise<void> {
    const session: AuthSession | null = this.currentSession;
    if (session === null) {
      return;
    }
    try {
      const recovery: EventRecoveryResponse = await this.realtimeApi.recoverSessionEvents(
        session.serverUrl, session.accessToken, this.currentSessionId, this.cursor);
      if (recovery.snapshotRequired) {
        const result: SessionDetailResult = await this.load(session, this.currentSessionId);
        this.onRows(result.rows);
        this.onSessionMeta(result.session);
        return;
      }
      let changed: boolean = false;
      recovery.events.forEach((event: EventEnvelope) => {
        if (this.applyEvent(event)) {
          changed = true;
        }
        this.cursor = event.cursor;
      });
      if (recovery.nextCursor !== undefined && recovery.nextCursor.length > 0) {
        this.cursor = recovery.nextCursor;
      }
      if (changed) {
        this.onRows(this.rows());
      }
    } catch (error) {
      // 补拉失败不阻塞实时通道，下一次重连会再试
    }
  }

  async respondNotice(noticeId: string, actionId: string, input?: Object): Promise<void> {
    const session: AuthSession | null = this.currentSession;
    if (session === null) {
      return;
    }
    await this.noticesApi.respond(session.serverUrl, session.accessToken, this.currentSessionId,
      noticeId, actionId, input);
    const refreshed = await this.noticesApi.list(session.serverUrl, session.accessToken,
      this.currentSessionId);
    this.notices.clear();
    refreshed.notices.forEach((notice: NoticeDto) => {
      this.notices.set(notice.noticeId, notice);
    });
    this.onNotices(this.openNotices());
  }

  hasMoreItems(): boolean {
    return this.hasMore;
  }

  getRuntimeState(): RuntimeStateDto | null {
    return this.runtimeState;
  }

  async refreshRuntimeState(): Promise<RuntimeStateDto | null> {
    const session: AuthSession | null = this.currentSession;
    if (session === null) {
      return null;
    }
    try {
      this.runtimeState = await this.runtimeApi.getState(session.serverUrl, session.accessToken,
        this.currentSessionId);
    } catch (error) {
      // 离线时保留快照里的状态
    }
    return this.runtimeState;
  }

  canLoadOlder(): boolean {
    return this.hasMore && !this.loadingOlder;
  }

  async loadOlder(): Promise<boolean> {
    const session: AuthSession | null = this.currentSession;
    if (session === null || !this.hasMore || this.loadingOlder || this.oldestOrderSeq <= 1) {
      return false;
    }
    this.loadingOlder = true;
    try {
      const page = await this.sessionsApi.loadTimelineHistory(session.serverUrl,
        session.accessToken, this.currentSessionId, this.oldestOrderSeq, 50);
      page.items.forEach((item: TimelineItemDto) => {
        this.items.set(item.id, item);
      });
      this.hasMore = page.hasMore;
      this.oldestOrderSeq = this.minOrderSeq();
      this.onRows(this.rows());
      return true;
    } finally {
      this.loadingOlder = false;
    }
  }

  private async markRead(): Promise<void> {
    const session: AuthSession | null = this.currentSession;
    if (session === null) {
      return;
    }
    try {
      await this.sessionsApi.markRead(session.serverUrl, session.accessToken, [this.currentSessionId]);
    } catch (error) {
      // 已读回执失败不影响阅读
    }
  }

  private minOrderSeq(): number {
    let min: number = 0;
    this.items.forEach((item: TimelineItemDto) => {
      if (min === 0 || item.orderSeq < min) {
        min = item.orderSeq;
      }
    });
    return min;
  }

  async setTakeover(enabled: boolean): Promise<SessionView> {
    const session: AuthSession | null = this.currentSession;
    if (session === null) {
      throw new Error('会话尚未加载');
    }
    const updated: SessionView = await this.runtimeApi.setTakeover(session.serverUrl,
      session.accessToken, this.currentSessionId, enabled);
    this.onSessionMeta(updated);
    return updated;
  }

  async interrupt(): Promise<void> {
    const session: AuthSession | null = this.currentSession;
    if (session === null) {
      throw new Error('会话尚未加载');
    }
    await this.runtimeApi.interrupt(session.serverUrl, session.accessToken, this.currentSessionId);
  }

  getPendingAttachments(): UploadedAttachment[] {
    return this.pendingAttachments;
  }

  async uploadAttachment(fileName: string, mediaType: string, data: ArrayBuffer): Promise<UploadedAttachment> {
    const session: AuthSession | null = this.currentSession;
    if (session === null) {
      throw new Error('未登录');
    }
    const uploaded: UploadedAttachment = await this.attachmentsApi.upload(session.serverUrl,
      session.accessToken, this.currentSessionId, fileName, mediaType, data);
    this.pendingAttachments.push(uploaded);
    return uploaded;
  }

  removePendingAttachment(index: number): void {
    if (index >= 0 && index < this.pendingAttachments.length) {
      this.pendingAttachments.splice(index, 1);
    }
  }

  async sendMessage(content: string): Promise<void> {
    const session: AuthSession | null = this.currentSession;
    if (session === null) {
      return;
    }
    const clientMessageId: string = `harmony-${Date.now()}`;
    const fileIds: string[] = [];
    this.pendingAttachments.forEach((attachment: UploadedAttachment) => {
      fileIds.push(attachment.fileId);
    });
    await this.sessionsApi.sendMessage(session.serverUrl, session.accessToken,
      this.currentSessionId, content, clientMessageId, fileIds);
    this.pendingAttachments = [];
  }

  private openNotices(): NoticeDto[] {
    const result: NoticeDto[] = [];
    this.notices.forEach((notice: NoticeDto) => {
      if (notice.status === 'open' || notice.status === 'responding') {
        result.push(notice);
      }
    });
    return result;
  }

  private rows(): TimelineRow[] {
    const all: TimelineItemDto[] = [];
    this.items.forEach((item: TimelineItemDto) => {
      all.push(item);
    });
    return toTimelineRows(all);
  }
}
