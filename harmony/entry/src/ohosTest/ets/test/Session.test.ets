import { describe, expect, it } from '@ohos/hypium';
import {
  groupSessions,
  SessionItem,
  SessionStatusKind,
  statusColor,
  statusLabel,
  textOf,
  toStatusKind
} from '../../../main/ets/model/Session';

function item(id: string, projectName: string, deviceName: string, sortAt: string): SessionItem {
  const row: SessionItem = {
    id: id,
    connectorId: 'c1',
    deviceName: deviceName,
    title: id,
    runtimeName: 'Codex',
    statusKind: SessionStatusKind.Idle,
    statusLabel: '空闲',
    unread: false,
    pinned: false,
    archived: false,
    takeover: false,
    updatedLabel: '',
    sortAt: sortAt,
    projectName: projectName
  };
  return row;
}

export default function sessionTest() {
  describe('session mapping', () => {
    it('maps status kinds', 0, () => {
      expect(toStatusKind('waiting_approval')).assertEqual(SessionStatusKind.WaitingApproval);
      expect(toStatusKind('error')).assertEqual(SessionStatusKind.Error);
      expect(toStatusKind('unknown-value')).assertEqual(SessionStatusKind.Idle);
    });
    it('labels and colors status', 0, () => {
      expect(statusLabel(SessionStatusKind.WaitingApproval).length > 0).assertTrue();
      expect(statusColor(SessionStatusKind.Error)).assertEqual('#D93026');
    });
    it('normalizes nullable text', 0, () => {
      expect(textOf(null)).assertEqual('');
      expect(textOf(undefined)).assertEqual('');
      expect(textOf('abc')).assertEqual('abc');
    });
    it('groups by project then device', 0, () => {
      const groups = groupSessions([
        item('a', 'Proj', 'Mac', '2026-10-18T10:00:00Z'),
        item('b', '', 'Mac', '2026-10-18T09:00:00Z'),
        item('c', 'Proj', 'Mac', '2026-10-18T08:00:00Z')
      ]);
      expect(groups.length).assertEqual(2);
      expect(groups[0].name.includes('Proj')).assertTrue();
      expect(groups[0].items.length).assertEqual(2);
      expect(groups[1].name.includes('Mac')).assertTrue();
    });
  });
}
