import { ConnectorView, ProjectView, SessionView } from '../../api/SessionDtos';
import { DevicesApi } from '../../api/DevicesApi';
import { SessionsApi } from '../../api/SessionsApi';
import { ProjectsApi } from '../../api/ProjectsApi';
import { AuthSession } from '../auth/AuthSessionStore';
import { relativeTime, SessionItem, SessionStatusKind, statusLabel, textOf, toStatusKind } from '../../model/Session';

export interface SessionsLoadResult {
  sessions: SessionItem[];
  hasMore: boolean;
  nextCursor: string;
}

/**
 * 会话列表控制器：拉取 /sessions 与 /connectors，合并设备名并按 pinned + 最近活动排序。
 * 对齐 Android feature/sessions/SessionsController.kt 的首屏逻辑。
 */
export class SessionsController {
  private readonly sessionsApi: SessionsApi;
  private readonly devicesApi: DevicesApi;
  private readonly projectsApi: ProjectsApi;

  constructor(sessionsApi: SessionsApi = new SessionsApi(), devicesApi: DevicesApi = new DevicesApi(),
    projectsApi: ProjectsApi = new ProjectsApi()) {
    this.sessionsApi = sessionsApi;
    this.devicesApi = devicesApi;
    this.projectsApi = projectsApi;
  }

  async load(session: AuthSession, archived: boolean, cursor?: string): Promise<SessionsLoadResult> {
    let deviceNames: Map<string, string> = new Map<string, string>();
    try {
      const devices = await this.devicesApi.listConnectors(session.serverUrl, session.accessToken);
      const connectors: ConnectorView[] = devices.connectors;
      connectors.forEach((connector: ConnectorView) => {
        deviceNames.set(connector.id, connector.name);
      });
    } catch (error) {
      // 设备名只是展示信息，失败时退回 connectorId
    }

    let projectNames: Map<string, string> = new Map<string, string>();
    try {
      const projects = await this.projectsApi.listProjects(session.serverUrl, session.accessToken);
      projects.projects.forEach((project: ProjectView) => {
        projectNames.set(project.id, project.name);
      });
    } catch (error) {
      // 项目名只是展示信息
    }

    const page = await this.sessionsApi.listSessions(session.serverUrl, session.accessToken, archived,
      20, cursor);
    const items: SessionItem[] = toSessionItems(page.sessions, deviceNames, projectNames);
    const nextCursor: string = page.nextCursor === null || page.nextCursor === undefined ?
      '' : page.nextCursor;
    return { sessions: items, hasMore: page.hasMore, nextCursor: nextCursor };
  }

  async setPinned(session: AuthSession, sessionId: string, pinned: boolean): Promise<void> {
    await this.sessionsApi.patchMeta(session.serverUrl, session.accessToken, sessionId,
      undefined, pinned, undefined);
  }

  async setArchived(session: AuthSession, sessionId: string, archived: boolean): Promise<void> {
    await this.sessionsApi.patchMeta(session.serverUrl, session.accessToken, sessionId,
      undefined, undefined, archived);
  }
}

export function toSessionItems(views: SessionView[], deviceNames: Map<string, string>,
  projectNames: Map<string, string>): SessionItem[] {
    const items: SessionItem[] = [];
    views.forEach((view: SessionView) => {
      const statusKind: SessionStatusKind = toStatusKind(view.status);
      const deviceName: string | undefined = deviceNames.get(view.connectorId);
      const runtimeNameValue: string = textOf(view.runtimeName);
      const runtimeName: string = runtimeNameValue.length > 0 ? runtimeNameValue : view.runtime;
      let sortAt: string = textOf(view.lastActivityAt);
      if (sortAt.length === 0) {
        sortAt = textOf(view.sortAt);
      }
      if (sortAt.length === 0) {
        sortAt = textOf(view.lastItemAt);
      }
      items.push({
        id: view.id,
        connectorId: view.connectorId,
        deviceName: deviceName !== undefined ? deviceName : view.connectorId,
        title: textOf(view.title).length > 0 ? textOf(view.title) : '未命名会话',
        runtimeName: runtimeName,
        statusKind: statusKind,
        statusLabel: statusLabel(statusKind),
        unread: view.unread,
        pinned: view.pinned,
        archived: view.archived,
        takeover: view.takeover,
        updatedLabel: relativeTime(sortAt),
        sortAt: sortAt,
        projectName: projectNames.get(view.projectId === null || view.projectId === undefined ?
          '' : view.projectId) ?? ''
      });
    });

    items.sort((left: SessionItem, right: SessionItem) => {
      if (left.pinned !== right.pinned) {
        return left.pinned ? -1 : 1;
      }
      if (left.sortAt === right.sortAt) {
        return 0;
      }
      return left.sortAt < right.sortAt ? 1 : -1;
    });
    return items;
}
