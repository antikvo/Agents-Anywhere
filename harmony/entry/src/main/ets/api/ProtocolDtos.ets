import { SessionView } from './SessionDtos';

/**
 * 会话快照与时间线条目的最小 DTO，字段来自 contracts/protocol/1.0 的
 * session-snapshot-response.schema.json。只声明渲染需要的字段。
 */

export interface TimelineItemDto {
  id: string;
  type: string;
  role?: string;
  content: Object;
  status: string;
  orderSeq: number;
  createdAt: string;
  updatedAt: string;
}

export interface TimelineSnapshotDto {
  items: TimelineItemDto[];
  hasMore: boolean;
  nextSeq: number;
}

export interface RuntimeStateDto {
  sessionId: string;
  runtime: string;
  runtimeId?: string | null;
  runtimeType?: string | null;
  externalSessionId?: string | null;
  status: string;
  selections: Record<string, string> | null;
  statusReason?: string | null;
  error?: Object | null;
  metadata?: Object | null;
  updatedSeq: number;
  createdAt?: string;
  updatedAt?: string;
}

export interface RuntimeStateResponse {
  state: RuntimeStateDto;
  serverTime: string;
}

export interface TimelineResponse {
  sessionId: string;
  items: TimelineItemDto[];
  nextSeq: number;
  hasMore: boolean;
  serverTime: string;
}

export interface SessionSnapshotResponse {
  session: SessionView;
  timeline: TimelineSnapshotDto;
  state?: RuntimeStateDto | null;
  notices?: NoticeDto[] | null;
  approvals?: Object[] | null;
  eventCursor: string;
  serverTime: string;
}

export interface NoticeActionDto {
  actionId: string;
  label: string;
  style?: string | null;
  input?: Object | null;
}

export interface NoticeDto {
  noticeId: string;
  type: string;
  sessionId: string;
  title: string;
  message?: string | null;
  interactionType?: string | null;
  status: string;
  severity?: string | null;
  responseRequired?: boolean;
  createdAt?: string | null;
  expiresAt?: string | null;
  actions?: NoticeActionDto[] | null;
  metadata?: Object | null;
}

export interface AttachmentRefDto {
  fileId: string;
  name: string;
  mediaType: string;
  size?: number;
  sha256?: string | null;
}

export interface TimelineContentFields {
  attachments?: AttachmentRefDto[] | null;
  text?: string | null;
  message?: string | null;
  rawText?: string | null;
  output?: string | null;
  command?: string | null;
  kind?: string | null;
  title?: string | null;
  subtitle?: string | null;
}
