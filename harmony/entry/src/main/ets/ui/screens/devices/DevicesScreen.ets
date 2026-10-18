import { AuthSession } from '../../../feature/auth/AuthSessionStore';
import { DevicesController } from '../../../feature/devices/DevicesController';
import { DeviceItem } from '../../../model/Device';
import { DevicesApi } from '../../../api/DevicesApi';
import { promptAction } from '@kit.ArkUI';
import { DeviceRuntimeItem, RuntimeTypeItem } from '../../../api/DeviceRuntimeDtos';

/**
 * 设备列表：名称、在线状态、系统与最后在线时间。
 * 设备详情里的 Runtime 配置需要在线 Connector，首版只做信息展示与降级提示。
 */
@Component
export struct DevicesScreen {
  session: AuthSession | null = null;
  private controller: DevicesController = new DevicesController();
  private devicesApi: DevicesApi = new DevicesApi();
  @State devices: DeviceItem[] = [];
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State selected: DeviceItem | null = null;
  @State showAdd: boolean = false;
  @State deviceName: string = '';
  @State creating: boolean = false;
  @State setupCommand: string = '';
  @State createError: string = '';
  @State renameMode: boolean = false;
  @State renameText: string = '';
  @State confirmDelete: boolean = false;
  @State actionBusy: boolean = false;
  @State runtimes: DeviceRuntimeItem[] = [];
  @State runtimesLoading: boolean = false;
  @State runtimesError: string = '';
  @State runtimeTypes: RuntimeTypeItem[] = [];
  @State discovering: boolean = false;
  @State addRuntimeType: string = '';
  @State addRuntimeTypeName: string = '';
  @State addRuntimeName: string = '';
  @State deleteRuntimeId: string = '';
  @State deleteRuntimeName: string = '';
  @State runtimeBusy: boolean = false;

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
      this.devices = await this.controller.load(session);
    } catch (error) {
      this.errorMessage = (error as Error).message;
    } finally {
      this.loading = false;
    }
  }

  private async loadRuntimes(connectorId: string): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null) {
      return;
    }
    this.runtimesLoading = true;
    this.runtimesError = '';
    this.runtimes = [];
    try {
      this.runtimes = await this.devicesApi.listRuntimes(session.serverUrl, session.accessToken,
        connectorId);
    } catch (error) {
      this.runtimesError = (error as Error).message;
    } finally {
      this.runtimesLoading = false;
    }
  }

  private async discoverRuntimes(): Promise<void> {
    const session: AuthSession | null = this.session;
    const selected: DeviceItem | null = this.selected;
    if (session === null || selected === null || this.discovering) {
      return;
    }
    this.discovering = true;
    this.runtimesError = '';
    try {
      this.runtimeTypes = await this.devicesApi.discoverRuntimeTypes(session.serverUrl,
        session.accessToken, selected.id);
      promptAction.showToast({ message: `发现 ${this.runtimeTypes.length} 种运行时` });
      await this.loadRuntimes(selected.id);
    } catch (error) {
      this.runtimesError = (error as Error).message;
    } finally {
      this.discovering = false;
    }
  }

  private async createRuntime(): Promise<void> {
    const session: AuthSession | null = this.session;
    const selected: DeviceItem | null = this.selected;
    if (session === null || selected === null || this.runtimeBusy ||
      this.addRuntimeName.trim().length === 0) {
      return;
    }
    this.runtimeBusy = true;
    this.runtimesError = '';
    try {
      await this.devicesApi.createRuntime(session.serverUrl, session.accessToken, selected.id,
        this.addRuntimeType, this.addRuntimeName.trim());
      promptAction.showToast({ message: '运行时实例已创建' });
      this.addRuntimeType = '';
      await this.loadRuntimes(selected.id);
    } catch (error) {
      this.runtimesError = (error as Error).message;
    } finally {
      this.runtimeBusy = false;
    }
  }

  private async deleteRuntime(): Promise<void> {
    const session: AuthSession | null = this.session;
    const selected: DeviceItem | null = this.selected;
    if (session === null || selected === null || this.runtimeBusy || this.deleteRuntimeId.length === 0) {
      return;
    }
    this.runtimeBusy = true;
    this.runtimesError = '';
    try {
      await this.devicesApi.deleteRuntimeConfig(session.serverUrl, session.accessToken, selected.id,
        this.deleteRuntimeId);
      promptAction.showToast({ message: '运行时实例已移除' });
      this.deleteRuntimeId = '';
      await this.loadRuntimes(selected.id);
    } catch (error) {
      this.runtimesError = (error as Error).message;
    } finally {
      this.runtimeBusy = false;
    }
  }

  private async renameDevice(): Promise<void> {
    const session: AuthSession | null = this.session;
    const selected: DeviceItem | null = this.selected;
    if (session === null || selected === null || this.renameText.trim().length === 0 || this.actionBusy) {
      return;
    }
    this.actionBusy = true;
    try {
      await this.controller.rename(session, selected.id, this.renameText);
      this.renameMode = false;
      this.selected = null;
      await this.load();
    } catch (error) {
      this.createError = (error as Error).message;
    } finally {
      this.actionBusy = false;
    }
  }

  private async deleteDevice(): Promise<void> {
    const session: AuthSession | null = this.session;
    const selected: DeviceItem | null = this.selected;
    if (session === null || selected === null || this.actionBusy) {
      return;
    }
    this.actionBusy = true;
    try {
      await this.controller.remove(session, selected.id);
      this.confirmDelete = false;
      this.selected = null;
      await this.load();
    } catch (error) {
      this.createError = (error as Error).message;
    } finally {
      this.actionBusy = false;
    }
  }

  private async createDevice(): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null || this.deviceName.trim().length === 0 || this.creating) {
      return;
    }
    this.creating = true;
    this.createError = '';
    try {
      const created = await this.controller.create(session, this.deviceName);
      this.setupCommand = `uvx anywhere-cli start --server-url ${session.serverUrl}` +
        ` --connector-id ${created.connector.id} --connector-token ${created.connectorToken}`;
      await this.load();
    } catch (error) {
      this.createError = (error as Error).message;
    } finally {
      this.creating = false;
    }
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('设备')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .layoutWeight(1)
          Button('添加')
            .height(30)
            .fontSize(12)
            .backgroundColor('#000000')
            .fontColor('#FFFFFF')
            .margin({ right: 8 })
            .onClick(() => {
              this.showAdd = true;
              this.setupCommand = '';
              this.createError = '';
            })
          Button('刷新')
            .height(30)
            .fontSize(12)
            .backgroundColor('#F2F2F2')
            .fontColor('#111111')
            .onClick(() => {
              this.load();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })

        if (this.loading) {
          Column() {
            LoadingProgress().width(40).height(40)
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.errorMessage.length > 0) {
          Column({ space: 12 }) {
            Text(this.errorMessage)
              .fontSize(14)
              .fontColor('#D93026')
              .textAlign(TextAlign.Center)
            Button('重试')
              .height(36)
              .onClick(() => {
                this.load();
              })
          }
          .layoutWeight(1)
          .width('100%')
          .padding(24)
          .justifyContent(FlexAlign.Center)
        } else if (this.devices.length === 0) {
          Column() {
            Text('还没有连接设备')
              .fontSize(14)
              .fontColor('#8A8A8A')
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 8 }) {
            ForEach(this.devices, (device: DeviceItem) => {
              ListItem() {
                Row({ space: 10 }) {
                  Column({ space: 4 }) {
                    Text(device.name)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#000000')
                    Text(`${device.deviceOs} · 最后在线 ${device.lastSeenLabel}`)
                      .fontSize(12)
                      .fontColor('#8A8A8A')
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Row({ space: 4 }) {
                    Circle()
                      .width(7)
                      .height(7)
                      .fill(device.online ? '#1F7A1F' : '#B0B0B0')
                    Text(device.statusLabel)
                      .fontSize(12)
                      .fontColor(device.online ? '#1F7A1F' : '#8A8A8A')
                  }
                }
                .width('100%')
                .padding(14)
                .borderRadius(10)
                .backgroundColor('#F7F7F7')
                .onClick(() => {
                  this.selected = device;
                  this.loadRuntimes(device.id);
                })
              }
            }, (device: DeviceItem) => device.id)
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
        }
      }
      .width('100%')
      .height('100%')

      if (this.selected !== null) {
        Column({ space: 10 }) {
          Row() {
            Text(this.selected.name)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000000')
              .layoutWeight(1)
            Button('关闭')
              .height(28)
              .fontSize(12)
              .backgroundColor('#F2F2F2')
              .fontColor('#111111')
              .onClick(() => {
                this.selected = null;
                this.renameMode = false;
                this.confirmDelete = false;
              })
          }
          .width('100%')

          Text(`状态：${this.selected.statusLabel}`)
            .fontSize(13)
            .fontColor('#333333')
            .width('100%')
          Text(`系统：${this.selected.deviceOs}`)
            .fontSize(13)
            .fontColor('#333333')
            .width('100%')
          Text(`设备 ID：${this.selected.id}`)
            .fontSize(12)
            .fontColor('#8A8A8A')
            .width('100%')
          Row({ space: 8 }) {
            Text('运行时')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#111111')
              .layoutWeight(1)
            Button(this.discovering ? '发现中' : '发现')
              .height(24)
              .fontSize(10)
              .backgroundColor('#F2F2F2')
              .fontColor('#111111')
              .enabled(!this.discovering)
              .onClick(() => {
                this.discoverRuntimes();
              })
            Button('刷新')
              .height(24)
              .fontSize(10)
              .backgroundColor('#F2F2F2')
              .fontColor('#111111')
              .onClick(() => {
                if (this.selected !== null) {
                  this.loadRuntimes(this.selected.id);
                }
              })
          }
          .width('100%')

          if (this.runtimesLoading) {
            Text('加载运行时…')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
          } else if (this.runtimesError.length > 0) {
            Text(this.runtimesError)
              .fontSize(12)
              .fontColor('#D93026')
              .width('100%')
          } else if (this.runtimes.length === 0) {
            Text('该设备还没有发现运行时；设备离线时只能查看缓存信息。')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
          } else {
            ForEach(this.runtimes, (runtime: DeviceRuntimeItem) => {
              Row({ space: 6 }) {
                Text(runtime.name.length > 0 ? runtime.name : runtime.typeDisplayName)
                  .fontSize(12)
                  .fontColor('#111111')
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(runtime.status)
                  .fontSize(10)
                  .fontColor(runtime.status === 'ready' || runtime.status === 'running' ?
                    '#1F7A1F' : '#8A8A8A')
                Text('移除')
                  .fontSize(10)
                  .fontColor('#D93026')
                  .padding({ left: 8 })
                  .onClick(() => {
                    this.deleteRuntimeId = runtime.runtimeId;
                    this.deleteRuntimeName = runtime.name;
                  })
              }
              .width('100%')
              .padding({ top: 4, bottom: 4 })
            }, (runtime: DeviceRuntimeItem) => runtime.runtimeId)
          }

          if (this.runtimeTypes.length > 0) {
            Text('已发现的运行时类型')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
            ForEach(this.runtimeTypes, (runtimeType: RuntimeTypeItem) => {
              Row({ space: 6 }) {
                Text(runtimeType.displayName)
                  .fontSize(12)
                  .fontColor('#111111')
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(runtimeType.available ? '可用' : (runtimeType.present ? '未就绪' : '未安装'))
                  .fontSize(10)
                  .fontColor(runtimeType.available ? '#1F7A1F' : '#8A8A8A')
                Text('添加')
                  .fontSize(10)
                  .fontColor('#111111')
                  .padding({ left: 8 })
                  .onClick(() => {
                    this.addRuntimeType = runtimeType.runtimeType;
                    this.addRuntimeTypeName = runtimeType.displayName;
                    this.addRuntimeName = `${runtimeType.displayName} 实例`;
                  })
              }
              .width('100%')
              .padding({ top: 4, bottom: 4 })
            }, (runtimeType: RuntimeTypeItem) => runtimeType.runtimeType)
          }

          if (!this.renameMode && !this.confirmDelete) {
            Row({ space: 8 }) {
              Button('重命名')
                .height(34)
                .fontSize(13)
                .backgroundColor('#F2F2F2')
                .fontColor('#111111')
                .onClick(() => {
                  this.renameText = this.selected !== null ? this.selected.name : '';
                  this.renameMode = true;
                })
              Button('删除')
                .height(34)
                .fontSize(13)
                .backgroundColor('#FDF1F0')
                .fontColor('#D93026')
                .onClick(() => {
                  this.confirmDelete = true;
                })
            }
            .width('100%')
          } else if (this.renameMode) {
            TextInput({ placeholder: '新的设备名称', text: this.renameText })
              .height(38)
              .fontSize(14)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .onChange((value: string) => {
                this.renameText = value;
              })
            Row({ space: 8 }) {
              Button('保存')
                .height(34)
                .fontSize(13)
                .enabled(!this.actionBusy)
                .onClick(() => {
                  this.renameDevice();
                })
              Button('取消')
                .height(34)
                .fontSize(13)
                .backgroundColor('#F2F2F2')
                .fontColor('#111111')
                .onClick(() => {
                  this.renameMode = false;
                })
            }
            .width('100%')
          } else {
            Text('删除后该设备需要重新添加并配置连接凭据。')
              .fontSize(12)
              .fontColor('#D93026')
              .width('100%')
            Row({ space: 8 }) {
              Button(this.actionBusy ? '删除中…' : '确认删除')
                .height(34)
                .fontSize(13)
                .backgroundColor('#D93026')
                .fontColor('#FFFFFF')
                .enabled(!this.actionBusy)
                .onClick(() => {
                  this.deleteDevice();
                })
              Button('取消')
                .height(34)
                .fontSize(13)
                .backgroundColor('#F2F2F2')
                .fontColor('#111111')
                .onClick(() => {
                  this.confirmDelete = false;
                })
            }
            .width('100%')
          }
        }
        .width('86%')
        .padding(16)
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
      }
      if (this.showAdd) {
        Column({ space: 10 }) {
          Row() {
            Text('添加设备')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000000')
              .layoutWeight(1)
            Button('关闭')
              .height(28)
              .fontSize(12)
              .backgroundColor('#F2F2F2')
              .fontColor('#111111')
              .onClick(() => {
                this.showAdd = false;
                this.deviceName = '';
                this.setupCommand = '';
                this.createError = '';
              })
          }
          .width('100%')

          if (this.setupCommand.length === 0) {
            Text('在需要接入的工作设备上执行下面命令。创建后 token 只显示一次。')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
            TextInput({ placeholder: '设备名称，例如 MacBook', text: this.deviceName })
              .height(40)
              .fontSize(14)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .onChange((value: string) => {
                this.deviceName = value;
              })
            if (this.createError.length > 0) {
              Text(this.createError)
                .fontSize(12)
                .fontColor('#D93026')
                .width('100%')
            }
            Button(this.creating ? '创建中…' : '创建并生成命令')
              .height(36)
              .enabled(!this.creating && this.deviceName.trim().length > 0)
              .onClick(() => {
                this.createDevice();
              })
          } else {
            Text('在工作设备上执行：')
              .fontSize(12)
              .fontColor('#8A8A8A')
              .width('100%')
            Text(this.setupCommand)
              .fontSize(12)
              .fontFamily('monospace')
              .fontColor('#111111')
              .width('100%')
              .padding(10)
              .borderRadius(8)
              .backgroundColor('#F5F5F5')
              .copyOption(CopyOptions.LocalDevice)
          }
        }
        .width('86%')
        .padding(16)
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
      }

      if (this.addRuntimeType.length > 0) {
        Column({ space: 10 }) {
          Text(`添加 ${this.addRuntimeTypeName} 实例`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .width('100%')
          TextInput({ placeholder: '实例名称', text: this.addRuntimeName })
            .height(40)
            .fontSize(14)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .onChange((value: string) => {
              this.addRuntimeName = value;
            })
          Text('使用默认配置创建；创建后可在客户端继续配置模型与权限。')
            .fontSize(11)
            .fontColor('#8A8A8A')
            .width('100%')
          Row({ space: 8 }) {
            Button(this.runtimeBusy ? '创建中…' : '创建')
              .height(34)
              .enabled(!this.runtimeBusy && this.addRuntimeName.trim().length > 0)
              .onClick(() => {
                this.createRuntime();
              })
            Button('取消')
              .height(34)
              .backgroundColor('#F2F2F2')
              .fontColor('#111111')
              .onClick(() => {
                this.addRuntimeType = '';
              })
          }
          .width('100%')
        }
        .width('86%')
        .padding(16)
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
      }

      if (this.deleteRuntimeId.length > 0) {
        Column({ space: 10 }) {
          Text('移除运行时实例')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .width('100%')
          Text(`确认移除「${this.deleteRuntimeName}」？该实例上的活跃会话将无法继续。`)
            .fontSize(12)
            .fontColor('#8A8A8A')
            .width('100%')
          Row({ space: 8 }) {
            Button(this.runtimeBusy ? '移除中…' : '确认移除')
              .height(34)
              .backgroundColor('#D93026')
              .fontColor('#FFFFFF')
              .enabled(!this.runtimeBusy)
              .onClick(() => {
                this.deleteRuntime();
              })
            Button('取消')
              .height(34)
              .backgroundColor('#F2F2F2')
              .fontColor('#111111')
              .onClick(() => {
                this.deleteRuntimeId = '';
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
