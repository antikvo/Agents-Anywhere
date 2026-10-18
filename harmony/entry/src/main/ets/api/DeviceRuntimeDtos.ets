export interface DeviceRuntimeItem {
  connectorId: string;
  runtimeId: string;
  runtimeType: string;
  name: string;
  displayName: string;
  typeDisplayName: string;
  present: boolean;
  available: boolean;
  configured: boolean;
  active: boolean;
  status: string;
  reason?: string | null;
}

export interface DeviceRuntimeListResponse {
  connectorId: string;
  runtimes: DeviceRuntimeItem[];
  serverTime: string;
}
