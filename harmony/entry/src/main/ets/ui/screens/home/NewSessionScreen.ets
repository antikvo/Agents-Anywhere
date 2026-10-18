import { AuthSession } from '../../../feature/auth/AuthSessionStore';
import { ConnectorView, ProjectView } from '../../../api/SessionDtos';
import { DevicesApi } from '../../../api/DevicesApi';
import { ProjectsApi } from '../../../api/ProjectsApi';
import { CreateAndStartBody, NewSessionApi } from '../../../api/NewSessionApi';
import { DeviceRuntimeItem, ModelCatalogItem, ModelReasoningItem } from '../../../api/DeviceRuntimeDtos';

/**
 * 新建会话：设备 → Runtime → 项目/工作区 → 模型 → 首条消息。
 * 使用 POST /sessions/create-and-start；失败时保留错误信息，不重复创建。
 */
@Component
export struct NewSessionScreen {
  session: AuthSession | null = null;
  onBack: () => void = () => {
  };
  onCreated: (sessionId: string) => void = () => {
  };
  private readonly devicesApi: DevicesApi = new DevicesApi();
  private readonly projectsApi: ProjectsApi = new ProjectsApi();
  private readonly newSessionApi: NewSessionApi = new NewSessionApi();
  @State connectors: ConnectorView[] = [];
  @State projects: ProjectView[] = [];
  private allProjects: ProjectView[] = [];
  @State runtimes: DeviceRuntimeItem[] = [];
  @State models: ModelCatalogItem[] = [];
  @State connectorId: string = '';
  @State runtimeId: string = '';
  @State projectId: string = '';
  @State cwd: string = '';
  @State content: string = '';
  @State selectionModel: string = '';
  @State selectionLabel: string = '';
  @State loading: boolean = true;
  @State creating: boolean = false;
  @State errorMessage: string = '';

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null) {
      this.loading = false;
      return;
    }
    this.loading = true;
    this.errorMessage = '';
    try {
      const devices = await this.devicesApi.listConnectors(session.serverUrl, session.accessToken);
      this.connectors = devices.connectors;
      try {
        const projects = await this.projectsApi.listProjects(session.serverUrl, session.accessToken);
        this.allProjects = projects.projects;
      } catch (error) {
        this.allProjects = [];
      }
      if (this.connectors.length > 0) {
        this.connectorId = this.connectors[0].id;
        this.applyProjects();
        await this.loadRuntimes();
      }
    } catch (error) {
      this.errorMessage = (error as Error).message;
    } finally {
      this.loading = false;
    }
  }

  private async loadRuntimes(): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null || this.connectorId.length === 0) {
      return;
    }
    this.runtimes = [];
    this.models = [];
    this.runtimeId = '';
    this.selectionModel = '';
    try {
      const all = await this.devicesApi.listRuntimes(session.serverUrl, session.accessToken,
        this.connectorId);
      this.runtimes = all.filter((runtime: DeviceRuntimeItem) => runtime.available);
      if (this.runtimes.length > 0) {
        this.runtimeId = this.runtimes[0].runtimeId;
        await this.loadModels();
      }
    } catch (error) {
      this.errorMessage = (error as Error).message;
    }
  }

  private async loadModels(): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null || this.runtimeId.length === 0) {
      return;
    }
    this.models = [];
    this.selectionModel = '';
    try {
      const catalog = await this.devicesApi.modelCatalog(session.serverUrl, session.accessToken,
        this.connectorId, this.runtimeId);
      this.models = catalog.catalog.models;
      if (this.models.length > 0 && this.models[0].reasoningItems.length > 0) {
        const first: ModelReasoningItem = this.models[0].reasoningItems[0];
        this.selectionModel = first.selectionId;
        this.selectionLabel = `${this.models[0].displayName} · ${first.displayName}`;
      }
    } catch (error) {
      this.models = [];
    }
  }

  private applyProjects(): void {
    this.projects = this.allProjects.filter((project: ProjectView) =>
    project.connectorId === this.connectorId);
    let matched: ProjectView | null = null;
    this.projects.forEach((project: ProjectView) => {
      if (project.id === this.projectId) {
        matched = project;
      }
    });
    if (matched !== null) {
      return;
    }
    this.projectId = '';
    if (this.projects.length > 0) {
      this.selectProject(this.projects[0]);
    }
  }

  private selectProject(project: ProjectView): void {
    this.projectId = project.id;
    this.cwd = project.workspacePath;
  }

  private async create(): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null || this.creating) {
      return;
    }
    if (this.connectorId.length === 0 || this.runtimeId.length === 0 ||
      this.projectId.length === 0 || this.cwd.trim().length === 0 ||
      this.content.trim().length === 0) {
      this.errorMessage = '请选择设备、Runtime 和项目，填写工作区与首条消息';
      return;
    }
    this.creating = true;
    this.errorMessage = '';
    try {
      const body: CreateAndStartBody = {
        connectorId: this.connectorId,
        runtime: this.runtimeTypeOf(this.runtimeId),
        runtimeId: this.runtimeId,
        cwd: this.cwd.trim(),
        content: this.content.trim()
      };
      body.projectId = this.projectId;
      if (this.selectionModel.length > 0) {
        const selections: Record<string, string> = {};
        selections['model'] = this.selectionModel;
        body.selections = selections;
      }
      const created = await this.newSessionApi.createAndStart(session.serverUrl,
        session.accessToken, body);
      this.onCreated(created.id);
    } catch (error) {
      this.errorMessage = (error as Error).message;
    } finally {
      this.creating = false;
    }
  }

  private runtimeTypeOf(runtimeId: string): string {
    let type: string = '';
    this.runtimes.forEach((runtime: DeviceRuntimeItem) => {
      if (runtime.runtimeId === runtimeId) {
        type = runtime.runtimeType;
      }
    });
    return type;
  }

  @Builder
  chip(label: string, selected: boolean, onTap: () => void) {
    Button(label)
      .height(28)
      .fontSize(11)
      .backgroundColor(selected ? '#000000' : '#F2F2F2')
      .fontColor(selected ? '#FFFFFF' : '#333333')
      .onClick(onTap)
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Button('返回')
          .height(32)
          .fontSize(13)
          .backgroundColor('#F2F2F2')
          .fontColor('#000000')
          .onClick(() => {
            this.onBack();
          })
        Text('新建会话')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#000000')
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      if (this.loading) {
        Column() {
          LoadingProgress().width(40).height(40)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 10 }) {
            if (this.errorMessage.length > 0) {
              Text(this.errorMessage)
                .fontSize(12)
                .fontColor('#D93026')
                .width('100%')
            }
            Text('设备')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
            Row({ space: 6 }) {
              ForEach(this.connectors, (connector: ConnectorView) => {
                this.chip(connector.name, this.connectorId === connector.id, () => {
                  this.connectorId = connector.id;
                  this.applyProjects();
                  this.loadRuntimes();
                })
              }, (connector: ConnectorView) => connector.id)
            }
            .width('100%')

            Text('Runtime')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
            if (this.runtimes.length === 0) {
              Text('该设备没有可用 Runtime，请先在设备详情里发现并启动。')
                .fontSize(12)
                .fontColor('#8A8A8A')
                .width('100%')
            } else {
              Row({ space: 6 }) {
                ForEach(this.runtimes, (runtime: DeviceRuntimeItem) => {
                  this.chip(runtime.name, this.runtimeId === runtime.runtimeId, () => {
                    this.runtimeId = runtime.runtimeId;
                    this.loadModels();
                  })
                }, (runtime: DeviceRuntimeItem) => runtime.runtimeId)
              }
              .width('100%')
            }

            Text('项目')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
            Row({ space: 6 }) {
              ForEach(this.projects, (project: ProjectView) => {
                this.chip(project.name, this.projectId === project.id, () => {
                  this.selectProject(project);
                })
              }, (project: ProjectView) => project.id)
            }
            .width('100%')

            Text('模型')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
            if (this.models.length === 0) {
              Text('未获取到模型列表，将使用 Runtime 默认模型。')
                .fontSize(12)
                .fontColor('#8A8A8A')
                .width('100%')
            } else {
              Column({ space: 6 }) {
                ForEach(this.models, (model: ModelCatalogItem) => {
                  Row({ space: 6 }) {
                    this.chip(model.displayName, this.selectionLabel.startsWith(model.displayName), () => {
                    })
                    ForEach(model.reasoningItems, (reasoning: ModelReasoningItem) => {
                      this.chip(reasoning.displayName, this.selectionModel === reasoning.selectionId, () => {
                        this.selectionModel = reasoning.selectionId;
                        this.selectionLabel = `${model.displayName} · ${reasoning.displayName}`;
                      })
                    }, (reasoning: ModelReasoningItem) => reasoning.selectionId)
                  }
                  .width('100%')
                }, (model: ModelCatalogItem) => model.id)
              }
              .width('100%')
            }

            Text('工作区路径')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
            TextInput({ placeholder: '/path/to/workspace', text: this.cwd })
              .height(40)
              .fontSize(13)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .onChange((value: string) => {
                this.cwd = value;
              })

            Text('首条消息')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
            TextArea({ placeholder: '描述要 Agent 做的第一件事', text: this.content })
              .height(100)
              .fontSize(13)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .onChange((value: string) => {
                this.content = value;
              })

            Button(this.creating ? '创建中…' : '创建并发送')
              .height(40)
              .width('100%')
              .enabled(!this.creating && this.connectorId.length > 0 &&
                this.runtimeId.length > 0 && this.projectId.length > 0 &&
                this.cwd.trim().length > 0 && this.content.trim().length > 0)
              .onClick(() => {
                this.create();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
