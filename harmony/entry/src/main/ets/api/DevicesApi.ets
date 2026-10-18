import { http } from '@kit.NetworkKit';
import { apiUrl } from '../core/ServerUrl';
import { HttpClient, HTTP_METHOD_POST, HTTP_METHOD_PATCH, HTTP_METHOD_DELETE, HTTP_METHOD_PUT } from './HttpClient';
import { ConnectorView, ConnectorsResponse } from './SessionDtos';
import { CreateRuntimeBody, DeviceRuntimeItem, DeviceRuntimeListResponse, RuntimeTypeItem, RuntimeTypeListResponse } from './DeviceRuntimeDtos';

export interface ConnectorCreateResponse {
  connector: ConnectorView;
  connectorToken: string;
  tokenPrefix: string;
}

interface CreateConnectorRequest {
  name: string;
  connectorKind: string;
}

interface ConnectorResponse {
  connector: ConnectorView;
  serverTime?: string;
}

interface UpdateConnectorRequest {
  name: string;
}

/**
 * 设备（Connector）列表 API，对齐 Android api/DevicesApi.kt 的列表部分。
 */
export class DevicesApi {
  private readonly client: HttpClient;

  constructor(client: HttpClient = new HttpClient()) {
    this.client = client;
  }

  async listRuntimes(serverUrl: string, token: string, connectorId: string): Promise<DeviceRuntimeItem[]> {
    const path: string = `/connectors/${encodeURIComponent(connectorId)}/runtimes`;
    const text: string = await this.client.requestJson(apiUrl(serverUrl, path), { token: token });
    const response: DeviceRuntimeListResponse = JSON.parse(text) as DeviceRuntimeListResponse;
    return response.runtimes;
  }

  async discoverRuntimeTypes(serverUrl: string, token: string,
    connectorId: string): Promise<RuntimeTypeItem[]> {
    const path: string = `/connectors/${encodeURIComponent(connectorId)}/runtime-types/discover`;
    const text: string = await this.client.requestJson(apiUrl(serverUrl, path), {
      method: HTTP_METHOD_POST,
      token: token,
      readTimeoutMs: 30000
    });
    const response: RuntimeTypeListResponse = JSON.parse(text) as RuntimeTypeListResponse;
    return response.runtimeTypes;
  }

  async createRuntime(serverUrl: string, token: string, connectorId: string, runtimeType: string,
    name: string): Promise<DeviceRuntimeItem> {
    const path: string = `/connectors/${encodeURIComponent(connectorId)}/runtimes`;
    const config: Record<string, Object> = {};
    const payload: CreateRuntimeBody = {
      runtimeType: runtimeType,
      name: name,
      config: config,
      active: false
    };
    const body: string = JSON.stringify(payload);
    const text: string = await this.client.requestJson(apiUrl(serverUrl, path), {
      method: HTTP_METHOD_POST,
      token: token,
      body: body,
      readTimeoutMs: 30000
    });
    return JSON.parse(text) as DeviceRuntimeItem;
  }

  async updateRuntimeConfig(serverUrl: string, token: string, connectorId: string,
    runtimeId: string, config: Record<string, Object>): Promise<DeviceRuntimeItem> {
    const path: string = `/connectors/${encodeURIComponent(connectorId)}/runtimes/` +
      `${encodeURIComponent(runtimeId)}/config`;
    const text: string = await this.client.requestJson(apiUrl(serverUrl, path), {
      method: HTTP_METHOD_PUT,
      token: token,
      body: JSON.stringify(config),
      readTimeoutMs: 30000
    });
    return JSON.parse(text) as DeviceRuntimeItem;
  }

  async deleteRuntimeConfig(serverUrl: string, token: string,
    connectorId: string, runtimeId: string): Promise<void> {
    const path: string = `/connectors/${encodeURIComponent(connectorId)}/runtimes/` +
      `${encodeURIComponent(runtimeId)}/config`;
    await this.client.requestJson(apiUrl(serverUrl, path), {
      method: HTTP_METHOD_DELETE,
      token: token
    });
  }

  async listConnectors(serverUrl: string, token: string): Promise<ConnectorsResponse> {
    const text: string = await this.client.requestJson(apiUrl(serverUrl, '/connectors'), { token: token });
    return JSON.parse(text) as ConnectorsResponse;
  }

  /**
   * 创建 Connector 并返回一次性 token；客户端展示启动命令，token 只出现这一次。
   */
  async updateConnector(serverUrl: string, token: string, connectorId: string,
    name: string): Promise<ConnectorView> {
    const path: string = `/connectors/${encodeURIComponent(connectorId)}`;
    const body: UpdateConnectorRequest = { name: name };
    const text: string = await this.client.requestJson(apiUrl(serverUrl, path), {
      method: HTTP_METHOD_PATCH,
      token: token,
      body: JSON.stringify(body)
    });
    const response: ConnectorResponse = JSON.parse(text) as ConnectorResponse;
    return response.connector;
  }

  async deleteConnector(serverUrl: string, token: string, connectorId: string): Promise<void> {
    const path: string = `/connectors/${encodeURIComponent(connectorId)}`;
    await this.client.requestJson(apiUrl(serverUrl, path), {
      method: HTTP_METHOD_DELETE,
      token: token
    });
  }

  async createConnector(serverUrl: string, token: string,
    name: string): Promise<ConnectorCreateResponse> {
    const body: CreateConnectorRequest = { name: name, connectorKind: 'cli' };
    const text: string = await this.client.requestJson(apiUrl(serverUrl, '/connectors'), {
      method: HTTP_METHOD_POST,
      token: token,
      body: JSON.stringify(body)
    });
    return JSON.parse(text) as ConnectorCreateResponse;
  }
}
