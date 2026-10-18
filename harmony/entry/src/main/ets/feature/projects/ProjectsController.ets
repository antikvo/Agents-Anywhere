import { DevicesApi } from '../../api/DevicesApi';
import { ProjectsApi } from '../../api/ProjectsApi';
import { ConnectorView, ProjectView } from '../../api/SessionDtos';
import { ProjectItem, toProjectItems } from '../../model/Project';
import { AuthSession } from '../auth/AuthSessionStore';

export class ProjectsController {
  private readonly api: ProjectsApi;
  private readonly devicesApi: DevicesApi;

  constructor(api: ProjectsApi = new ProjectsApi(), devicesApi: DevicesApi = new DevicesApi()) {
    this.api = api;
    this.devicesApi = devicesApi;
  }

  async load(session: AuthSession): Promise<ProjectItem[]> {
    const projects = await this.api.listProjects(session.serverUrl, session.accessToken);
    let connectors: ConnectorView[] = [];
    try {
      const devices = await this.devicesApi.listConnectors(session.serverUrl, session.accessToken);
      connectors = devices.connectors;
    } catch (error) {
      // 设备名只是展示信息
    }
    return toProjectItems(projects.projects, connectors);
  }

  async create(session: AuthSession, name: string, connectorId: string,
    workspacePath: string): Promise<ProjectView> {
    return await this.api.createProject(session.serverUrl, session.accessToken, name.trim(),
      connectorId, workspacePath.trim());
  }

  async rename(session: AuthSession, projectId: string, name: string): Promise<ProjectView> {
    return await this.api.renameProject(session.serverUrl, session.accessToken, projectId,
      name.trim());
  }

  async archiveAll(session: AuthSession, projectId: string, archived: boolean): Promise<number> {
    const result = await this.api.archiveAllSessions(session.serverUrl, session.accessToken,
      projectId, archived, 'active');
    return result.affected;
  }

  async remove(session: AuthSession, projectId: string): Promise<number> {
    return await this.api.deleteProject(session.serverUrl, session.accessToken, projectId);
  }
}
