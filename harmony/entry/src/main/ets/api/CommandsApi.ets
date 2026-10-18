import { apiUrl } from '../core/ServerUrl';
import { HttpClient } from './HttpClient';

export interface RuntimeCommand {
  id: string;
  title: string;
  description?: string | null;
  aliases: string[];
  category?: string | null;
  enabled: boolean;
  acceptsArgs: boolean;
}

interface CommandListResponse {
  commands: RuntimeCommand[];
  serverTime: string;
}

/**
 * Runtime 命令列表（会话输入框「/」建议）。
 * 不同 Runtime 支持程度不同，未实现时返回空数组。
 */
export class CommandsApi {
  private readonly client: HttpClient;

  constructor(client: HttpClient = new HttpClient()) {
    this.client = client;
  }

  async list(serverUrl: string, token: string, connectorId: string,
    runtimeId: string): Promise<RuntimeCommand[]> {
    if (connectorId.length === 0 || runtimeId.length === 0) {
      return [];
    }
    const path: string = `/connectors/${encodeURIComponent(connectorId)}/runtimes/` +
      `${encodeURIComponent(runtimeId)}/commands`;
    const text: string = await this.client.requestJson(apiUrl(serverUrl, path), { token: token });
    const response: CommandListResponse = JSON.parse(text) as CommandListResponse;
    return response.commands;
  }
}
