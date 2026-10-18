import { DevicesApi } from '../../../api/DevicesApi';
import { ConnectorView } from '../../../api/SessionDtos';
import { ProjectsController } from '../../../feature/projects/ProjectsController';
import { ProjectItem } from '../../../model/Project';
import { AuthSession } from '../../../feature/auth/AuthSessionStore';
import { FilesScreen } from '../files/FilesScreen';

/**
 * 项目管理：列表、新建（名称/工作区/设备）、重命名、删除。
 * 工作区路径需要用户手填，与服务端 project.workspacePath 一致。
 */
@Component
export struct ProjectsScreen {
  session: AuthSession | null = null;
  onBack: () => void = () => {
  };
  private controller: ProjectsController = new ProjectsController();
  private devicesApi: DevicesApi = new DevicesApi();
  @State projects: ProjectItem[] = [];
  @State connectors: ConnectorView[] = [];
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State showForm: boolean = false;
  @State name: string = '';
  @State workspacePath: string = '';
  @State selectedConnectorId: string = '';
  @State busy: boolean = false;
  @State renameId: string = '';
  @State renameText: string = '';
  @State deleteId: string = '';
  @State showFiles: boolean = false;
  @State filesConnectorId: string = '';
  @State filesRoot: string = '';
  @State filesTitle: string = '';

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
      this.projects = await this.controller.load(session);
      const devices = await this.devicesApi.listConnectors(session.serverUrl, session.accessToken);
      this.connectors = devices.connectors;
      if (this.connectors.length > 0 && this.selectedConnectorId.length === 0) {
        this.selectedConnectorId = this.connectors[0].id;
      }
    } catch (error) {
      this.errorMessage = (error as Error).message;
    } finally {
      this.loading = false;
    }
  }

  private async createProject(): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null || this.busy || this.name.trim().length === 0 ||
      this.workspacePath.trim().length === 0 || this.selectedConnectorId.length === 0) {
      return;
    }
    this.busy = true;
    this.errorMessage = '';
    try {
      await this.controller.create(session, this.name, this.selectedConnectorId, this.workspacePath);
      this.showForm = false;
      this.name = '';
      this.workspacePath = '';
      await this.load();
    } catch (error) {
      this.errorMessage = (error as Error).message;
    } finally {
      this.busy = false;
    }
  }

  private async renameProject(): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null || this.busy || this.renameText.trim().length === 0) {
      return;
    }
    this.busy = true;
    try {
      await this.controller.rename(session, this.renameId, this.renameText);
      this.renameId = '';
      await this.load();
    } catch (error) {
      this.errorMessage = (error as Error).message;
    } finally {
      this.busy = false;
    }
  }

  private async deleteProject(): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null || this.busy || this.deleteId.length === 0) {
      return;
    }
    this.busy = true;
    try {
      await this.controller.remove(session, this.deleteId);
      this.deleteId = '';
      await this.load();
    } catch (error) {
      this.errorMessage = (error as Error).message;
    } finally {
      this.busy = false;
    }
  }

  build() {
    Stack() {
      if (this.showFiles) {
        FilesScreen({
          session: this.session,
          connectorId: this.filesConnectorId,
          root: this.filesRoot,
          title: this.filesTitle,
          onBack: () => {
            this.showFiles = false;
          }
        })
      } else {
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
          Text('项目')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
          Blank()
          Button(this.showForm ? '取消' : '新建')
            .height(32)
            .fontSize(13)
            .backgroundColor(this.showForm ? '#F2F2F2' : '#000000')
            .fontColor(this.showForm ? '#000000' : '#FFFFFF')
            .onClick(() => {
              this.showForm = !this.showForm;
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(12)
            .fontColor('#D93026')
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 6 })
        }

        if (this.showForm) {
          Column({ space: 8 }) {
            TextInput({ placeholder: '项目名称', text: this.name })
              .height(40)
              .fontSize(14)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .onChange((value: string) => {
                this.name = value;
              })
            TextInput({ placeholder: '工作区路径，例如 /Users/me/code/app', text: this.workspacePath })
              .height(40)
              .fontSize(14)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .onChange((value: string) => {
                this.workspacePath = value;
              })
            Text('所属设备')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
            if (this.connectors.length === 0) {
              Text('还没有可用设备，先在「设备」里添加。')
                .fontSize(12)
                .fontColor('#8A8A8A')
                .width('100%')
            } else {
              Row({ space: 6 }) {
                ForEach(this.connectors, (connector: ConnectorView) => {
                  Button(connector.name)
                    .height(28)
                    .fontSize(11)
                    .backgroundColor(this.selectedConnectorId === connector.id ? '#000000' : '#F2F2F2')
                    .fontColor(this.selectedConnectorId === connector.id ? '#FFFFFF' : '#333333')
                    .onClick(() => {
                      this.selectedConnectorId = connector.id;
                    })
                }, (connector: ConnectorView) => connector.id)
              }
              .width('100%')
            }
            Button(this.busy ? '创建中…' : '创建项目')
              .height(38)
              .width('100%')
              .enabled(!this.busy && this.name.trim().length > 0 &&
                this.workspacePath.trim().length > 0 && this.selectedConnectorId.length > 0)
              .onClick(() => {
                this.createProject();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
        }

        if (this.loading) {
          Column() {
            LoadingProgress().width(40).height(40)
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.projects.length === 0) {
          Column() {
            Text('还没有项目')
              .fontSize(14)
              .fontColor('#8A8A8A')
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 8 }) {
            ForEach(this.projects, (project: ProjectItem) => {
              ListItem() {
                Column({ space: 6 }) {
                  Row({ space: 6 }) {
                    Text(project.name)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#000000')
                      .layoutWeight(1)
                    Button('文件')
                      .height(24)
                      .fontSize(10)
                      .backgroundColor('#EAEAEA')
                      .fontColor('#444444')
                      .onClick(() => {
                        this.filesConnectorId = project.connectorId;
                        this.filesRoot = project.workspacePath;
                        this.filesTitle = project.name;
                        this.showFiles = true;
                      })
                    Button('重命名')
                      .height(24)
                      .fontSize(10)
                      .backgroundColor('#EAEAEA')
                      .fontColor('#444444')
                      .onClick(() => {
                        this.renameId = project.id;
                        this.renameText = project.name;
                      })
                    Button('删除')
                      .height(24)
                      .fontSize(10)
                      .backgroundColor('#FDF1F0')
                      .fontColor('#D93026')
                      .onClick(() => {
                        this.deleteId = project.id;
                      })
                  }
                  .width('100%')
                  Text(`${project.deviceName} · ${project.workspacePath}`)
                    .fontSize(12)
                    .fontColor('#8A8A8A')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')
                .padding(14)
                .borderRadius(10)
                .backgroundColor('#F7F7F7')
              }
            }, (project: ProjectItem) => project.id)
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
        }
      }
      .width('100%')
      .height('100%')
      }

      if (this.renameId.length > 0) {
        Column({ space: 10 }) {
          Text('重命名项目')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .width('100%')
          TextInput({ placeholder: '项目名称', text: this.renameText })
            .height(40)
            .fontSize(14)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .onChange((value: string) => {
              this.renameText = value;
            })
          Row({ space: 8 }) {
            Button('保存')
              .height(34)
              .enabled(!this.busy)
              .onClick(() => {
                this.renameProject();
              })
            Button('取消')
              .height(34)
              .backgroundColor('#F2F2F2')
              .fontColor('#111111')
              .onClick(() => {
                this.renameId = '';
              })
          }
          .width('100%')
        }
        .width('86%')
        .padding(16)
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
      }

      if (this.deleteId.length > 0) {
        Column({ space: 10 }) {
          Text('删除项目')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .width('100%')
          Text('删除后项目下的会话会脱离项目分组，但不会被删除。')
            .fontSize(12)
            .fontColor('#8A8A8A')
            .width('100%')
          Row({ space: 8 }) {
            Button(this.busy ? '删除中…' : '确认删除')
              .height(34)
              .backgroundColor('#D93026')
              .fontColor('#FFFFFF')
              .enabled(!this.busy)
              .onClick(() => {
                this.deleteProject();
              })
            Button('取消')
              .height(34)
              .backgroundColor('#F2F2F2')
              .fontColor('#111111')
              .onClick(() => {
                this.deleteId = '';
              })
          }
          .width('100%')
        }
        .width('86%')
        .padding(16)
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }
}
