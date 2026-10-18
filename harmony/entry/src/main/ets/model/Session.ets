/**
 * 会话的应用内模型与状态映射。
 * 对齐 Android model/AgentSession.kt 的 SessionStatus 与展示字段。
 */
export enum SessionStatusKind {
  Idle = 'idle',
  Waiting = 'waiting',
  Pending = 'pending',
  Running = 'running',
  Stopping = 'stopping',
  WaitingApproval = 'waiting_approval',
  Error = 'error',
  Blocked = 'blocked'
}

export interface SessionItem {
  id: string;
  connectorId: string;
  deviceName: string;
  title: string;
  runtimeName: string;
  statusKind: SessionStatusKind;
  statusLabel: string;
  unread: boolean;
  pinned: boolean;
  archived: boolean;
  takeover: boolean;
  updatedLabel: string;
  sortAt: string;
  projectName: string;
}

export interface SessionGroup {
  name: string;
  items: SessionItem[];
}

/**
 * 有项目的会话按项目分组，其余按设备名分组；组内保持原有排序。
 */
export function groupSessions(items: SessionItem[]): SessionGroup[] {
  const order: string[] = [];
  const buckets: Map<string, SessionItem[]> = new Map<string, SessionItem[]>();
  items.forEach((item: SessionItem) => {
    let key: string = item.deviceName.length > 0 ? item.deviceName : '未知设备';
    if (item.projectName.length > 0) {
      key = `项目 · ${item.projectName}`;
    }
    const bucket: SessionItem[] | undefined = buckets.get(key);
    if (bucket === undefined) {
      buckets.set(key, [item]);
      order.push(key);
    } else {
      bucket.push(item);
    }
  });
  const groups: SessionGroup[] = [];
  order.forEach((key: string) => {
    const bucket: SessionItem[] | undefined = buckets.get(key);
    if (bucket !== undefined) {
      groups.push({ name: key, items: bucket });
    }
  });
  return groups;
}

export function textOf(value: string | null | undefined): string {
  return value === null || value === undefined ? '' : value;
}

export function toStatusKind(raw: string): SessionStatusKind {
  switch (raw) {
    case 'waiting':
      return SessionStatusKind.Waiting;
    case 'pending':
      return SessionStatusKind.Pending;
    case 'running':
      return SessionStatusKind.Running;
    case 'stopping':
      return SessionStatusKind.Stopping;
    case 'waiting_approval':
      return SessionStatusKind.WaitingApproval;
    case 'error':
      return SessionStatusKind.Error;
    case 'blocked':
      return SessionStatusKind.Blocked;
    default:
      return SessionStatusKind.Idle;
  }
}

export function statusLabel(kind: SessionStatusKind): string {
  switch (kind) {
    case SessionStatusKind.Waiting:
      return '等待中';
    case SessionStatusKind.Pending:
      return '处理中';
    case SessionStatusKind.Running:
      return '运行中';
    case SessionStatusKind.Stopping:
      return '停止中';
    case SessionStatusKind.WaitingApproval:
      return '待审批';
    case SessionStatusKind.Error:
      return '出错';
    case SessionStatusKind.Blocked:
      return '已阻塞';
    default:
      return '空闲';
  }
}

export function statusColor(kind: SessionStatusKind): string {
  switch (kind) {
    case SessionStatusKind.Running:
    case SessionStatusKind.Pending:
      return '#1F7A1F';
    case SessionStatusKind.WaitingApproval:
      return '#B26B00';
    case SessionStatusKind.Error:
      return '#D93026';
    case SessionStatusKind.Blocked:
      return '#8A5A00';
    default:
      return '#8A8A8A';
  }
}

/**
 * 相对时间：优先 lastActivityAt / sortAt，按 分钟 / 小时 / 天 展示。
 */
export function relativeTime(iso?: string): string {
  if (iso === undefined || iso.length === 0) {
    return '';
  }
  const then: number = Date.parse(iso);
  if (Number.isNaN(then)) {
    return '';
  }
  const diffMs: number = Date.now() - then;
  if (diffMs < 0) {
    return '刚刚';
  }
  const minutes: number = Math.floor(diffMs / 60000);
  if (minutes < 1) {
    return '刚刚';
  }
  if (minutes < 60) {
    return `${minutes} 分钟前`;
  }
  const hours: number = Math.floor(minutes / 60);
  if (hours < 24) {
    return `${hours} 小时前`;
  }
  const days: number = Math.floor(hours / 24);
  if (days < 30) {
    return `${days} 天前`;
  }
  const date: Date = new Date(then);
  const month: string = `${date.getMonth() + 1}`.padStart(2, '0');
  const day: string = `${date.getDate()}`.padStart(2, '0');
  return `${month}-${day}`;
}
