import { ConnectorCreateResponse, DevicesApi } from '../../api/DevicesApi';
import { DeviceItem, toDeviceItems } from '../../model/Device';
import { AuthSession } from '../auth/AuthSessionStore';

export class DevicesController {
  private readonly api: DevicesApi;

  constructor(api: DevicesApi = new DevicesApi()) {
    this.api = api;
  }

  async load(session: AuthSession): Promise<DeviceItem[]> {
    const response = await this.api.listConnectors(session.serverUrl, session.accessToken);
    return toDeviceItems(response.connectors);
  }

  async create(session: AuthSession, name: string): Promise<ConnectorCreateResponse> {
    return await this.api.createConnector(session.serverUrl, session.accessToken, name.trim());
  }

  async rename(session: AuthSession, connectorId: string, name: string): Promise<void> {
    await this.api.updateConnector(session.serverUrl, session.accessToken, connectorId, name.trim());
  }

  async remove(session: AuthSession, connectorId: string): Promise<void> {
    await this.api.deleteConnector(session.serverUrl, session.accessToken, connectorId);
  }
}
