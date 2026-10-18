import { AttachmentRefDto, TimelineContentFields, TimelineItemDto } from '../api/ProtocolDtos';

/**
 * 时间线条目到 UI 行的映射。
 *
 * 首版只区分四类行：用户消息、Agent 消息、工具调用、系统提示。
 * 完整的 11 类条目（reasoning / file_change / notice / artifact 等）
 * 在后续任务里按 Android SessionTimelineProjection 的规则补齐。
 */
export enum TimelineRowKind {
  UserMessage = 'user_message',
  AgentMessage = 'agent_message',
  ToolCall = 'tool_call',
  SystemNotice = 'system_notice',
  Artifact = 'artifact'
}

export interface FileChange {
  path: string;
  diff: string;
  kind: string;
}

export interface TimelineRow {
  id: string;
  kind: TimelineRowKind;
  title: string;
  command: string;
  systemLabel: string;
  body: string;
  reasoning: string;
  fileChanges: FileChange[];
  status: string;
  timeLabel: string;
  attachments: AttachmentRefDto[];
}

function commandOf(content: Object): string {
  if (typeof content === 'string') {
    return '';
  }
  const fields: TimelineContentFields = content as TimelineContentFields;
  const command: string | null | undefined = fields.command;
  return command === undefined || command === null ? '' : command;
}

interface RawChangeKind {
  type?: string;
  move_path?: string | null;
}

interface RawChange {
  path?: string | null;
  diff?: string | null;
  kind?: RawChangeKind | null;
}

function fileChangesOf(content: Object): FileChange[] {
  if (typeof content === 'string') {
    return [];
  }
  const fields: TimelineContentFields = content as TimelineContentFields;
  const rawChanges: Object[] = fields.changes === undefined || fields.changes === null ?
    [] : fields.changes;
  const basePath: string = fields.path === undefined || fields.path === null ? '' : fields.path;
  const result: FileChange[] = [];
  rawChanges.forEach((item: Object) => {
    const change: RawChange = item as RawChange;
    const diff: string = change.diff === undefined || change.diff === null ? '' : change.diff;
    const path: string = change.path === undefined || change.path === null ? basePath : change.path;
    let kind: string = 'update';
    if (change.kind !== undefined && change.kind !== null) {
      const rawKind: RawChangeKind = change.kind;
      if (rawKind.type !== undefined && rawKind.type !== null && rawKind.type.length > 0) {
        kind = rawKind.type;
      }
    }
    result.push({ path: path, diff: diff, kind: kind });
  });
  return result;
}

function systemLabelOf(content: Object): string {
  if (typeof content === 'string') {
    return '';
  }
  const fields: TimelineContentFields = content as TimelineContentFields;
  const kind: string | null | undefined = fields.kind;
  return kind === undefined || kind === null ? '' : kind;
}

function contentText(content: Object): string {
  if (typeof content === 'string') {
    return content as string;
  }
  const fields: TimelineContentFields = content as TimelineContentFields;
  const candidates: (string | null | undefined)[] = [fields.output, fields.text, fields.message,
    fields.rawText, fields.command];
  for (let i = 0; i < candidates.length; i++) {
    const value: string | null | undefined = candidates[i];
    if (value !== undefined && value !== null && value.length > 0) {
      return value;
    }
  }
  return '';
}

function timeLabel(iso: string): string {
  if (iso.length === 0) {
    return '';
  }
  const timestamp: number = Date.parse(iso);
  if (Number.isNaN(timestamp)) {
    return '';
  }
  const date: Date = new Date(timestamp);
  const hours: string = `${date.getHours()}`.padStart(2, '0');
  const minutes: string = `${date.getMinutes()}`.padStart(2, '0');
  return `${hours}:${minutes}`;
}

function contentAttachments(content: Object): AttachmentRefDto[] {
  if (typeof content === 'string') {
    return [];
  }
  const fields: TimelineContentFields = content as TimelineContentFields;
  const attachments: AttachmentRefDto[] | null | undefined = fields.attachments;
  return attachments === undefined || attachments === null ? [] : attachments;
}

function kindOf(item: TimelineItemDto): TimelineRowKind {
  if (item.type === 'artifact') {
    return TimelineRowKind.Artifact;
  }
  if (item.type === 'tool' || item.role === 'tool') {
    return TimelineRowKind.ToolCall;
  }
  if (item.role === 'user') {
    return TimelineRowKind.UserMessage;
  }
  if (item.role === 'assistant') {
    return TimelineRowKind.AgentMessage;
  }
  return TimelineRowKind.SystemNotice;
}

function toolTitle(content: Object): string {
  if (typeof content === 'string') {
    return '工具调用';
  }
  const fields: TimelineContentFields = content as TimelineContentFields;
  const kind: string | null | undefined = fields.kind;
  const title: string | null | undefined = fields.title;
  if (title !== undefined && title !== null && title.length > 0) {
    return title;
  }
  if (kind !== undefined && kind !== null && kind.length > 0) {
    return kind;
  }
  return '工具调用';
}

export function toTimelineRows(items: TimelineItemDto[]): TimelineRow[] {
  const sorted: TimelineItemDto[] = items.slice();
  sorted.sort((left: TimelineItemDto, right: TimelineItemDto) => left.orderSeq - right.orderSeq);
  const rows: TimelineRow[] = [];
  sorted.forEach((item: TimelineItemDto) => {
    const kind: TimelineRowKind = kindOf(item);
    const rawContent: Object | null = item.content === null || item.content === undefined ? null : item.content;
    const body: string = rawContent === null ? '' : contentText(rawContent);
    const row: TimelineRow = {
      id: item.id,
      kind: kind,
      title: kind === TimelineRowKind.ToolCall && rawContent !== null ? toolTitle(rawContent) : '',
      command: kind === TimelineRowKind.ToolCall && rawContent !== null ? commandOf(rawContent) : '',
      systemLabel: rawContent === null ? '' : systemLabelOf(rawContent),
      body: body,
      reasoning: rawContent !== null && systemLabelOf(rawContent) === 'reasoning' ? body : '',
      fileChanges: rawContent === null ? [] : fileChangesOf(rawContent),
      status: item.status,
      timeLabel: timeLabel(item.createdAt),
      attachments: rawContent === null ? [] : contentAttachments(rawContent)
    };
    rows.push(row);
  });
  return rows;
}
