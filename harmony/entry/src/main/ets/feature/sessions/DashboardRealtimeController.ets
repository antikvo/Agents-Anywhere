import { DashboardSnapshotMessage, RealtimeApi } from '../../api/RealtimeApi';
import { RealtimeClient } from '../../api/RealtimeClient';
import { ConnectorView, ProjectView, SessionView } from '../../api/SessionDtos';
import { AuthSession } from '../auth/AuthSessionStore';
import { toSessionItems } from './SessionsController';
import { SessionItem } from '../../model/Session';

/**
 * Dashboard 实时通道：接收 dashboard.snapshot 并映射为会话列表。
 * 对齐 Android feature/realtime/DashboardRealtimeController.kt 的首屏语义。
 */
export class DashboardRealtimeController {
  private readonly realtime: RealtimeClient = new RealtimeClient();
  private readonly realtimeApi: RealtimeApi = new RealtimeApi();
  private readonly clientId: string = `harmony-dash-${Date.now()}`;

  onSessions: (items: SessionItem[]) => void = () => {
  };
  onState: (connected: boolean) => void = () => {
  };

  async start(session: AuthSession): Promise<void> {
    try {
      const ticket = await this.realtimeApi.createDashboardTicket(session.serverUrl,
        session.accessToken, this.clientId);
      const url: string = this.realtimeApi.dashboardSocketUrl(session.serverUrl, ticket.ticket);
      this.realtime.connect(url, {
        onOpen: () => {
          this.onState(true);
        },
        onMessage: (text: string) => {
          this.handleMessage(text);
        },
        onClose: (reason: string) => {
          this.onState(false);
        },
        onError: (message: string) => {
          this.onState(false);
        }
      });
    } catch (error) {
      this.onState(false);
    }
  }

  stop(): void {
    this.realtime.disconnect();
  }

  private handleMessage(text: string): void {
    let message: DashboardSnapshotMessage;
    try {
      message = JSON.parse(text) as DashboardSnapshotMessage;
    } catch (error) {
      return;
    }
    if (message.type !== 'dashboard.snapshot') {
      return;
    }
    const sessions: SessionView[] = message.sessions === undefined || message.sessions === null ?
      [] : message.sessions;
    const connectors: ConnectorView[] = message.connectors === undefined || message.connectors === null ?
      [] : message.connectors;
    const deviceNames: Map<string, string> = new Map<string, string>();
    connectors.forEach((connector: ConnectorView) => {
      deviceNames.set(connector.id, connector.name);
    });
    const projectNames: Map<string, string> = new Map<string, string>();
    const projects: ProjectView[] = message.projects === undefined || message.projects === null ?
      [] : message.projects;
    projects.forEach((project: ProjectView) => {
      projectNames.set(project.id, project.name);
    });
    this.onSessions(toSessionItems(sessions, deviceNames, projectNames));
  }
}
