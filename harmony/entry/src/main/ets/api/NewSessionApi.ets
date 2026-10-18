import { apiUrl } from '../core/ServerUrl';
import { HttpClient, HTTP_METHOD_POST } from './HttpClient';
import { SessionView } from './SessionDtos';

export interface CreateAndStartBody {
  connectorId: string;
  runtime: string;
  runtimeId: string;
  cwd: string;
  content: string;
  projectId?: string;
  selections?: Record<string, string>;
}

interface CreateAndStartResponse {
  session: SessionView;
  connectorResult?: Object | null;
}

export class NewSessionApi {
  private readonly client: HttpClient;

  constructor(client: HttpClient = new HttpClient()) {
    this.client = client;
  }

  async createAndStart(serverUrl: string, token: string,
    body: CreateAndStartBody): Promise<SessionView> {
    const text: string = await this.client.requestJson(apiUrl(serverUrl, '/sessions/create-and-start'), {
      method: HTTP_METHOD_POST,
      token: token,
      body: JSON.stringify(body),
      readTimeoutMs: 60000
    });
    const response: CreateAndStartResponse = JSON.parse(text) as CreateAndStartResponse;
    return response.session;
  }
}
