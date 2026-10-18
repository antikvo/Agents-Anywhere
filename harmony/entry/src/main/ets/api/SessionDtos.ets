/**
 * 会话与设备 DTO，字段对齐 server/agent_server/core/models.py 的 SessionView / ConnectorView。
 * 只声明客户端用到的字段，其余字段忽略。
 */

export interface SessionView {
  id: string;
  connectorId: string;
  projectId?: string | null;
  connectorStatus: string;
  runtime: string;
  runtimeId?: string | null;
  runtimeType?: string | null;
  runtimeName?: string | null;
  externalSessionId?: string | null;
  title?: string | null;
  cwd?: string | null;
  status: string;
  takeover: boolean;
  pinned: boolean;
  pinnedAt?: string | null;
  archived: boolean;
  archivedAt?: string | null;
  unread: boolean;
  lastReadSeq: number;
  latestTurnEndSeq?: number;
  lastSyncedAt?: string | null;
  lastActivityAt?: string | null;
  lastItemAt?: string | null;
  sortAt?: string | null;
  updatedSeq: number;
}

export interface SessionsPageResponse {
  sessions: SessionView[];
  hasMore: boolean;
  nextCursor?: string | null;
  serverTime: string;
}

export interface ProjectView {
  id: string;
  connectorId: string;
  name: string;
  workspacePath: string;
  pinned: boolean;
}

export interface ProjectsResponse {
  projects: ProjectView[];
  serverTime: string;
}

export interface ConnectorView {
  id: string;
  name: string;
  deviceOs?: string | null;
  status: string;
  lastSeenAt?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface ConnectorsResponse {
  connectors: ConnectorView[];
  serverTime: string;
}
