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

export interface RuntimeTypeItem {
  connectorId: string;
  runtimeType: string;
  displayName: string;
  description?: string | null;
  present: boolean;
  available: boolean;
  reason?: string | null;
  recommended: boolean;
  maxInstances?: number | null;
}

export interface RuntimeTypeListResponse {
  connectorId: string;
  runtimeTypes: RuntimeTypeItem[];
  serverTime: string;
}
