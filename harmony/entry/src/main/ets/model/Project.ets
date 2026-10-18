import { ConnectorView, ProjectView } from '../api/SessionDtos';

export interface ProjectItem {
  id: string;
  name: string;
  workspacePath: string;
  connectorId: string;
  deviceName: string;
  pinned: boolean;
}

export function toProjectItems(projects: ProjectView[], connectors: ConnectorView[]): ProjectItem[] {
  const devices: Map<string, string> = new Map<string, string>();
  connectors.forEach((connector: ConnectorView) => {
    devices.set(connector.id, connector.name);
  });
  const items: ProjectItem[] = [];
  projects.forEach((project: ProjectView) => {
    const deviceName: string = devices.get(project.connectorId) ?? project.connectorId;
    items.push({
      id: project.id,
      name: project.name,
      workspacePath: project.workspacePath,
      connectorId: project.connectorId,
      deviceName: deviceName,
      pinned: project.pinned
    });
  });
  return items;
}
