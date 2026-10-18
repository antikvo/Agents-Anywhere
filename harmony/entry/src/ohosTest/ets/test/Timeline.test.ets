import { describe, expect, it } from '@ohos/hypium';
import { toTimelineRows, TimelineRowKind } from '../../../main/ets/model/Timeline';
import { TimelineItemDto } from '../../../main/ets/api/ProtocolDtos';

interface TextContent {
  kind: string;
  text: string;
}

interface CommandContent {
  kind: string;
  command: string;
  output: string;
}

interface ChangeKind {
  type: string;
}

interface ChangeItem {
  path: string;
  diff: string;
  kind: ChangeKind;
}

interface ArtifactContent {
  kind: string;
  changes: ChangeItem[];
}

interface MarkerContent {
  kind: string;
  label: string;
}

function item(id: string, type: string, role: string, content: Object): TimelineItemDto {
  const dto: TimelineItemDto = {
    id: id,
    type: type,
    role: role,
    content: content,
    status: 'done',
    orderSeq: 1,
    createdAt: '2026-10-18T00:00:00Z',
    updatedAt: '2026-10-18T00:00:00Z'
  };
  return dto;
}

export default function timelineTest() {
  describe('toTimelineRows', () => {
    it('maps a user message', 0, () => {
      const content: TextContent = { kind: 'markdown', text: 'hi' };
      const rows = toTimelineRows([item('i1', 'message', 'user', content)]);
      expect(rows.length).assertEqual(1);
      expect(rows[0].kind).assertEqual(TimelineRowKind.UserMessage);
      expect(rows[0].body).assertEqual('hi');
    });
    it('maps a tool command with output', 0, () => {
      const content: CommandContent = { kind: 'command', command: 'ls -la', output: 'file.txt' };
      const rows = toTimelineRows([item('i2', 'tool', 'tool', content)]);
      expect(rows[0].kind).assertEqual(TimelineRowKind.ToolCall);
      expect(rows[0].command).assertEqual('ls -la');
      expect(rows[0].body).assertEqual('file.txt');
    });
    it('maps a file-change artifact', 0, () => {
      const change: ChangeItem = {
        path: 'a.ts',
        diff: '+1',
        kind: { type: 'update' } as ChangeKind
      };
      const content: ArtifactContent = { kind: 'file_change', changes: [change] };
      const rows = toTimelineRows([item('i3', 'artifact', '', content)]);
      expect(rows[0].kind).assertEqual(TimelineRowKind.Artifact);
      expect(rows[0].fileChanges.length).assertEqual(1);
      expect(rows[0].fileChanges[0].path).assertEqual('a.ts');
    });
    it('maps reasoning text', 0, () => {
      const content: TextContent = { kind: 'reasoning', text: 'thinking' };
      const rows = toTimelineRows([item('i4', 'system', 'system', content)]);
      expect(rows[0].kind).assertEqual(TimelineRowKind.SystemNotice);
      expect(rows[0].reasoning).assertEqual('thinking');
    });
    it('maps a compact marker label', 0, () => {
      const content: MarkerContent = { kind: 'compact', label: '对话已压缩' };
      const rows = toTimelineRows([item('i5', 'marker', '', content)]);
      expect(rows[0].markerLabel).assertEqual('对话已压缩');
    });
  });
}
