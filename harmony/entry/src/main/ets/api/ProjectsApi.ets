import { apiUrl } from '../core/ServerUrl';
import { HTTP_METHOD_DELETE, HTTP_METHOD_PATCH, HTTP_METHOD_POST, HttpClient } from './HttpClient';
import { ProjectView, ProjectsResponse } from './SessionDtos';

interface ProjectResponse {
  project: ProjectView;
  serverTime: string;
}

interface CreateProjectRequest {
  name: string;
  connectorId: string;
  workspacePath: string;
}

interface PatchProjectRequest {
  name?: string;
  pinned?: boolean;
}

interface DeleteProjectResponse {
  projectId: string;
  detachedSessions: number;
  serverTime: string;
}

export class ProjectsApi {
  private readonly client: HttpClient;

  constructor(client: HttpClient = new HttpClient()) {
    this.client = client;
  }

  async listProjects(serverUrl: string, token: string): Promise<ProjectsResponse> {
    const text: string = await this.client.requestJson(apiUrl(serverUrl, '/projects'), { token: token });
    return JSON.parse(text) as ProjectsResponse;
  }

  async createProject(serverUrl: string, token: string, name: string, connectorId: string,
    workspacePath: string): Promise<ProjectView> {
    const body: CreateProjectRequest = {
      name: name,
      connectorId: connectorId,
      workspacePath: workspacePath
    };
    const text: string = await this.client.requestJson(apiUrl(serverUrl, '/projects'), {
      method: HTTP_METHOD_POST,
      token: token,
      body: JSON.stringify(body)
    });
    const response: ProjectResponse = JSON.parse(text) as ProjectResponse;
    return response.project;
  }

  async renameProject(serverUrl: string, token: string, projectId: string,
    name: string): Promise<ProjectView> {
    const body: PatchProjectRequest = { name: name };
    const text: string = await this.client.requestJson(
      apiUrl(serverUrl, `/projects/${encodeURIComponent(projectId)}`), {
        method: HTTP_METHOD_PATCH,
        token: token,
        body: JSON.stringify(body)
      });
    const response: ProjectResponse = JSON.parse(text) as ProjectResponse;
    return response.project;
  }

  async deleteProject(serverUrl: string, token: string, projectId: string): Promise<number> {
    const text: string = await this.client.requestJson(
      apiUrl(serverUrl, `/projects/${encodeURIComponent(projectId)}`), {
        method: HTTP_METHOD_DELETE,
        token: token
      });
    const response: DeleteProjectResponse = JSON.parse(text) as DeleteProjectResponse;
    return response.detachedSessions;
  }
}
