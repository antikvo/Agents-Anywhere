import { http } from '@kit.NetworkKit';
import { apiUrl, webSocketUrl } from '../core/ServerUrl';
import { ConnectorView, ProjectView, SessionView } from './SessionDtos';
import { HttpClient } from './HttpClient';

/**
 * 实时通道 DTO 与请求封装。
 * 对齐 Android api/RealtimeApi.kt：先 POST /ws-ticket，再连 /sessions/{id}/ws?ticket=。
 */

export interface WsTicketResponse {
  ticket: string;
  expiresAt: string;
  serverTime?: string;
}

export interface EventEnvelope {
  protocolVersion: string;
  eventId: string;
  sequence: number;
  cursor: string;
  type: string;
  sessionId: string;
  emittedAt: string;
  payload: Object;
}

export interface DashboardSnapshotMessage {
  type: string;
  sessions?: SessionView[] | null;
  connectors?: ConnectorView[] | null;
  projects?: ProjectView[] | null;
  serverTime?: string;
}

export interface EventRecoveryResponse {
  events: EventEnvelope[];
  nextCursor: string;
  snapshotRequired: boolean;
  serverTime?: string;
}

interface TicketScope {
  sessionId?: string;
  dashboard?: boolean;
}

interface TicketRequest {
  clientId: string;
  scope: TicketScope;
}

export class RealtimeApi {
  private readonly client: HttpClient;

  constructor(client: HttpClient = new HttpClient()) {
    this.client = client;
  }

  async createSessionTicket(serverUrl: string, token: string, clientId: string,
    sessionId: string): Promise<WsTicketResponse> {
    const scope: TicketScope = { sessionId: sessionId };
    const payload: TicketRequest = { clientId: clientId, scope: scope };
    const text: string = await this.client.requestJson(apiUrl(serverUrl, '/ws-ticket'), {
      method: http.RequestMethod.POST,
      token: token,
      body: JSON.stringify(payload)
    });
    return JSON.parse(text) as WsTicketResponse;
  }

  async createDashboardTicket(serverUrl: string, token: string, clientId: string): Promise<WsTicketResponse> {
    const scope: TicketScope = { dashboard: true };
    const payload: TicketRequest = { clientId: clientId, scope: scope };
    const text: string = await this.client.requestJson(apiUrl(serverUrl, '/ws-ticket'), {
      method: http.RequestMethod.POST,
      token: token,
      body: JSON.stringify(payload)
    });
    return JSON.parse(text) as WsTicketResponse;
  }

  dashboardSocketUrl(serverUrl: string, ticket: string): string {
    return webSocketUrl(serverUrl, `/dashboard/ws?ticket=${encodeURIComponent(ticket)}`);
  }

  sessionSocketUrl(serverUrl: string, sessionId: string, ticket: string): string {
    return webSocketUrl(serverUrl,
      `/sessions/${encodeURIComponent(sessionId)}/ws?ticket=${encodeURIComponent(ticket)}`);
  }

  async recoverSessionEvents(serverUrl: string, token: string, sessionId: string,
    after: string): Promise<EventRecoveryResponse> {
    const path: string = `/sessions/${encodeURIComponent(sessionId)}/events?after=${encodeURIComponent(after)}`;
    const text: string = await this.client.requestJson(apiUrl(serverUrl, path), { token: token });
    return JSON.parse(text) as EventRecoveryResponse;
  }
}
