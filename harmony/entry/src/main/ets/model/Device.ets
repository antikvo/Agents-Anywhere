import { ConnectorView } from '../api/SessionDtos';

export interface DeviceItem {
  id: string;
  name: string;
  online: boolean;
  statusLabel: string;
  deviceOs: string;
  lastSeenLabel: string;
}

export function relativeSeen(iso?: string | null): string {
  if (iso === null || iso === undefined || iso.length === 0) {
    return '未知';
  }
  const then: number = Date.parse(iso);
  if (Number.isNaN(then)) {
    return '未知';
  }
  const minutes: number = Math.floor((Date.now() - then) / 60000);
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
  return `${Math.floor(hours / 24)} 天前`;
}

export function toDeviceItems(connectors: ConnectorView[]): DeviceItem[] {
  const items: DeviceItem[] = [];
  connectors.forEach((connector: ConnectorView) => {
    const online: boolean = connector.status === 'online';
    items.push({
      id: connector.id,
      name: connector.name,
      online: online,
      statusLabel: online ? '在线' : '离线',
      deviceOs: connector.deviceOs === null || connector.deviceOs === undefined ?
        '未知系统' : connector.deviceOs,
      lastSeenLabel: relativeSeen(connector.lastSeenAt)
    });
  });
  items.sort((left: DeviceItem, right: DeviceItem) => {
    if (left.online !== right.online) {
      return left.online ? -1 : 1;
    }
    return left.name < right.name ? -1 : 1;
  });
  return items;
}
