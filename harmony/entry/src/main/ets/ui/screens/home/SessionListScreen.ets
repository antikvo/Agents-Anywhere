import { AuthSession } from '../../../feature/auth/AuthSessionStore';
import { SessionsController, SessionsLoadResult } from '../../../feature/sessions/SessionsController';
import { DashboardRealtimeController } from '../../../feature/sessions/DashboardRealtimeController';
import { groupSessions, SessionGroup, SessionItem, statusColor } from '../../../model/Session';
import { DevicesScreen } from '../devices/DevicesScreen';

/**
 * 会话列表页（M1 第一块）。
 * 当前支持：活跃 / 已归档切换、下拉刷新按钮、loading / 空态 / 错误重试、设备与状态展示。
 * 会话详情、新建会话、分组与搜索在后续任务中补齐。
 */
@Component
export struct SessionListScreen {
  session: AuthSession | null = null;
  accountLabel: string = '';
  onSignOut: () => void = () => {
  };
  onOpenSession: (item: SessionItem) => void = () => {
  };
  onOpenSettings: () => void = () => {
  };
  @Prop @Watch('onDeepLinkPropChanged') pendingDeepLink: string = '';
  onDeepLinkConsumed: () => void = () => {
  };
  private controller: SessionsController = new SessionsController();
  private dashboard: DashboardRealtimeController = new DashboardRealtimeController();
  @State sessions: SessionItem[] = [];
  @State allSessions: SessionItem[] = [];
  @State archived: boolean = false;
  @State loading: boolean = false;
  @State errorMessage: string = '';
  @State liveConnected: boolean = false;
  @State nextCursor: string = '';
  @State hasMore: boolean = false;
  @State loadingMore: boolean = false;
  @State actionError: string = '';
  @State query: string = '';
  @State showDevices: boolean = false;
  @State groups: SessionGroup[] = [];

  onDeepLinkPropChanged(): void {
    this.tryConsumeDeepLink();
  }

  private tryConsumeDeepLink(): void {
    const target: string = this.pendingDeepLink;
    if (target.length === 0) {
      return;
    }
    for (let i = 0; i < this.allSessions.length; i++) {
      const item: SessionItem = this.allSessions[i];
      if (item.id === target) {
        this.onDeepLinkConsumed();
        this.onOpenSession(item);
        return;
      }
    }
  }

  aboutToAppear(): void {
    this.dashboard.onSessions = (items: SessionItem[]) => {
      this.allSessions = items;
      this.applyFilter();
    };
    this.dashboard.onState = (connected: boolean) => {
      this.liveConnected = connected;
    };
    this.reload();
    const session: AuthSession | null = this.session;
    if (session !== null) {
      this.dashboard.start(session);
    }
  }

  aboutToDisappear(): void {
    this.dashboard.stop();
  }

  private applyFilter(): void {
    const visible: SessionItem[] = [];
    const keyword: string = this.query.trim().toLowerCase();
    this.allSessions.forEach((item: SessionItem) => {
      if (item.archived !== this.archived) {
        return;
      }
      if (keyword.length === 0) {
        visible.push(item);
        return;
      }
      const haystack: string = `${item.title} ${item.deviceName} ${item.runtimeName}`.toLowerCase();
      if (haystack.includes(keyword)) {
        visible.push(item);
      }
    });
    this.sessions = visible;
    this.groups = groupSessions(visible);
    this.tryConsumeDeepLink();
  }

  private async reload(): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null) {
      return;
    }
    this.loading = true;
    this.errorMessage = '';
    try {
      const result: SessionsLoadResult = await this.controller.load(session, this.archived);
      this.allSessions = result.sessions;
      this.nextCursor = result.nextCursor;
      this.hasMore = result.hasMore;
      this.applyFilter();
    } catch (error) {
      this.errorMessage = (error as Error).message;
    } finally {
      this.loading = false;
    }
  }

  private async loadMore(): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null || !this.hasMore || this.loadingMore || this.nextCursor.length === 0) {
      return;
    }
    this.loadingMore = true;
    try {
      const result: SessionsLoadResult = await this.controller.load(session, this.archived, this.nextCursor);
      const existingIds: Set<string> = new Set<string>();
      this.allSessions.forEach((item: SessionItem) => {
        existingIds.add(item.id);
      });
      result.sessions.forEach((item: SessionItem) => {
        if (!existingIds.has(item.id)) {
          this.allSessions.push(item);
        }
      });
      this.nextCursor = result.nextCursor;
      this.hasMore = result.hasMore;
      this.applyFilter();
    } catch (error) {
      this.actionError = (error as Error).message;
    } finally {
      this.loadingMore = false;
    }
  }

  private async togglePin(item: SessionItem): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null) {
      return;
    }
    this.actionError = '';
    try {
      await this.controller.setPinned(session, item.id, !item.pinned);
      this.reload();
    } catch (error) {
      this.actionError = (error as Error).message;
    }
  }

  private async toggleArchive(item: SessionItem): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null) {
      return;
    }
    this.actionError = '';
    try {
      await this.controller.setArchived(session, item.id, !this.archived);
      this.reload();
    } catch (error) {
      this.actionError = (error as Error).message;
    }
  }

  @Builder
  groupHeader(name: string) {
    Row() {
      Text(name)
        .fontSize(12)
        .fontColor('#8A8A8A')
      Blank()
    }
    .width('100%')
    .padding({ top: 8, bottom: 2, left: 4, right: 4 })
  }

  @Builder
  rowMenu(item: SessionItem) {
    Menu() {
      MenuItem({ content: item.pinned ? '取消置顶' : '置顶' })
        .onClick(() => {
          this.togglePin(item);
        })
      MenuItem({ content: this.archived ? '恢复' : '归档' })
        .onClick(() => {
          this.toggleArchive(item);
        })
    }
  }

  @Builder
  pinAction(item: SessionItem) {
    Button(item.pinned ? '取消置顶' : '置顶')
      .width(88)
      .height('100%')
      .fontSize(13)
      .backgroundColor('#4A4A4A')
      .fontColor('#FFFFFF')
      .onClick(() => {
        this.togglePin(item);
      })
  }

  @Builder
  archiveAction(item: SessionItem) {
    Button(this.archived ? '恢复' : '归档')
      .width(88)
      .height('100%')
      .fontSize(13)
      .backgroundColor(this.archived ? '#1F7A1F' : '#D93026')
      .fontColor('#FFFFFF')
      .onClick(() => {
        this.toggleArchive(item);
      })
  }

  private switchTab(archived: boolean): void {
    if (this.archived === archived) {
      return;
    }
    this.showDevices = false;
    this.archived = archived;
    this.sessions = [];
    this.allSessions = [];
    this.reload();
  }

  build() {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text('Agents Anywhere')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
          Row({ space: 4 }) {
            Text(this.accountLabel.length > 0 ? this.accountLabel : '—')
              .fontSize(12)
              .fontColor('#8A8A8A')
            Circle()
              .width(6)
              .height(6)
              .fill(this.liveConnected ? '#1F7A1F' : '#C0C0C0')
            Text(this.liveConnected ? '实时' : '离线')
              .fontSize(11)
              .fontColor(this.liveConnected ? '#1F7A1F' : '#8A8A8A')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('刷新')
          .height(32)
          .fontSize(13)
          .backgroundColor('#F2F2F2')
          .fontColor('#000000')
          .onClick(() => {
            this.reload();
          })

        Button('设置')
          .height(32)
          .fontSize(13)
          .margin({ left: 8 })
          .backgroundColor('#F2F2F2')
          .fontColor('#111111')
          .onClick(() => {
            this.onOpenSettings();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Row({ space: 8 }) {
        Button('活跃')
          .height(32)
          .fontSize(13)
          .layoutWeight(1)
          .backgroundColor(!this.showDevices && !this.archived ? '#000000' : '#F2F2F2')
          .fontColor(!this.showDevices && !this.archived ? '#FFFFFF' : '#000000')
          .onClick(() => {
            this.switchTab(false);
          })
        Button('已归档')
          .height(32)
          .fontSize(13)
          .layoutWeight(1)
          .backgroundColor(!this.showDevices && this.archived ? '#000000' : '#F2F2F2')
          .fontColor(!this.showDevices && this.archived ? '#FFFFFF' : '#000000')
          .onClick(() => {
            this.switchTab(true);
          })
        Button('设备')
          .height(32)
          .fontSize(13)
          .layoutWeight(1)
          .backgroundColor(this.showDevices ? '#000000' : '#F2F2F2')
          .fontColor(this.showDevices ? '#FFFFFF' : '#000000')
          .onClick(() => {
            this.showDevices = true;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      if (this.showDevices) {
        Column() {
          DevicesScreen({ session: this.session })
        }
        .layoutWeight(1)
        .width('100%')
      } else {
      TextInput({ placeholder: '搜索会话', text: this.query })
        .height(40)
        .fontSize(14)
        .borderRadius(10)
        .backgroundColor('#F5F5F5')
        .margin({ left: 16, right: 16, bottom: 8 })
        .onChange((value: string) => {
          this.query = value;
          this.applyFilter();
        })

      if (this.actionError.length > 0) {
        Text(this.actionError)
          .fontSize(12)
          .fontColor('#D93026')
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 4 })
      }

      if (this.loading && this.sessions.length === 0) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMessage.length > 0 && this.sessions.length === 0) {
        Column({ space: 12 }) {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor('#D93026')
            .textAlign(TextAlign.Center)
          Button('重试')
            .height(36)
            .onClick(() => {
              this.reload();
            })
        }
        .layoutWeight(1)
        .width('100%')
        .padding(24)
        .justifyContent(FlexAlign.Center)
      } else if (this.sessions.length === 0) {
        Column() {
          Text(this.archived ? '没有已归档的会话' : '还没有会话')
            .fontSize(14)
            .fontColor('#8A8A8A')
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.groups, (group: SessionGroup) => {
            ListItemGroup({ header: this.groupHeader(group.name) }) {
              ForEach(group.items, (item: SessionItem) => {
            ListItem() {
              Row({ space: 10 }) {
                Column({ space: 4 }) {
                  Row({ space: 6 }) {
                    if (item.unread) {
                      Circle().width(7).height(7).fill('#D93026')
                    }
                    if (item.pinned) {
                      Text('置顶')
                        .fontSize(10)
                        .fontColor('#B26B00')
                        .backgroundColor('#FDF6EC')
                        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                        .borderRadius(4)
                    }
                    Text(item.title)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#000000')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                  }
                  .width('100%')

                  Text(`${item.deviceName} · ${item.runtimeName}${item.updatedLabel.length > 0 ? ' · ' + item.updatedLabel : ''}`)
                    .fontSize(12)
                    .fontColor('#8A8A8A')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .onClick(() => {
                  this.onOpenSession(item);
                })

                Column({ space: 6 }) {
                  Row({ space: 4 }) {
                    Circle()
                      .width(7)
                      .height(7)
                      .fill(statusColor(item.statusKind))
                    Text(item.statusLabel)
                      .fontSize(12)
                      .fontColor(statusColor(item.statusKind))
                  }
                  Row({ space: 6 }) {
                    Button(item.pinned ? '取消置顶' : '置顶')
                      .height(24)
                      .fontSize(10)
                      .padding({ left: 8, right: 8 })
                      .backgroundColor('#EAEAEA')
                      .fontColor('#444444')
                      .onClick(() => {
                        this.togglePin(item);
                      })
                    Button(this.archived ? '恢复' : '归档')
                      .height(24)
                      .fontSize(10)
                      .padding({ left: 8, right: 8 })
                      .backgroundColor('#EAEAEA')
                      .fontColor('#444444')
                      .onClick(() => {
                        this.toggleArchive(item);
                      })
                  }
                }
                .alignItems(HorizontalAlign.End)
              }
              .width('100%')
              .padding(14)
              .borderRadius(10)
              .backgroundColor('#F7F7F7')
            }
            .swipeAction({ start: this.pinAction(item), end: this.archiveAction(item) })
            .bindContextMenu(this.rowMenu(item), ResponseType.LongPress)
              }, (item: SessionItem) => item.id)
            }
          }, (group: SessionGroup) => group.name)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 16 })
        .onReachEnd(() => {
          this.loadMore();
        })
      }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
