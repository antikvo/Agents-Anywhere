import { FilesApi, FsEntryDto, FsTextResult } from '../../../api/FilesApi';
import { AppContextHolder } from '../../../core/AppContextHolder';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { fileUri } from '@kit.CoreFileKit';
import { AuthSession } from '../../../feature/auth/AuthSessionStore';

/**
 * 设备文件浏览：目录列举 + 文本预览。
 * 需要在线 Connector；离线时展示服务端 409 的降级提示。
 */
@Component
export struct FilesScreen {
  session: AuthSession | null = null;
  connectorId: string = '';
  root: string = '';
  title: string = '';
  onBack: () => void = () => {
  };
  private api: FilesApi = new FilesApi();
  @State path: string = '.';
  @State entries: FsEntryDto[] = [];
  @State loading: boolean = true;
  @State errorMessage: string = '';
  @State preview: FsTextResult | null = null;
  @State imagePath: string = '';
  @State imageName: string = '';
  @State imageLoading: boolean = false;

  aboutToAppear(): void {
    this.load('.');
  }

  private async load(path: string): Promise<void> {
    const session: AuthSession | null = this.session;
    if (session === null || this.connectorId.length === 0) {
      this.loading = false;
      return;
    }
    this.loading = true;
    this.errorMessage = '';
    try {
      const result = await this.api.list(session.serverUrl, session.accessToken, this.connectorId,
        this.root, path);
      this.path = result.path;
      this.entries = result.entries;
    } catch (error) {
      const message: string = (error as Error).message;
      this.errorMessage = message.toLowerCase().includes('offline') ?
        '设备离线：文件浏览需要在线 Connector。' : message;
      this.entries = [];
    } finally {
      this.loading = false;
    }
  }

  private async openEntry(entry: FsEntryDto): Promise<void> {
    if (entry.type === 'directory') {
      await this.load(entry.name);
      return;
    }
    const session: AuthSession | null = this.session;
    if (session === null) {
      return;
    }
    this.errorMessage = '';
    const lower: string = entry.name.toLowerCase();
    const isImage: boolean = lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') ||
      lower.endsWith('.gif') || lower.endsWith('.webp') || lower.endsWith('.bmp');
    if (isImage) {
      this.imageLoading = true;
      this.imagePath = '';
      try {
        const path: string = await this.api.readBytesToCache(session.serverUrl, session.accessToken,
          this.connectorId, this.root, entry.name, AppContextHolder.require().cacheDir);
        this.imageName = entry.name;
        this.imagePath = `file://${path}`;
      } catch (error) {
        this.errorMessage = (error as Error).message;
      } finally {
        this.imageLoading = false;
      }
      return;
    }
    try {
      this.preview = await this.api.readText(session.serverUrl, session.accessToken, this.connectorId,
        this.root, entry.name);
    } catch (error) {
      const message: string = (error as Error).message;
      this.errorMessage = message.toLowerCase().includes('offline') ?
        '设备离线：文本预览需要在线 Connector。' : message;
    }
  }

  build() {
    Stack() {
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
          Column({ space: 2 }) {
            Text(this.title.length > 0 ? this.title : '文件')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000000')
            Text(this.path)
              .fontSize(11)
              .fontColor('#8A8A8A')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Button('刷新')
            .height(30)
            .fontSize(12)
            .backgroundColor('#F2F2F2')
            .fontColor('#111111')
            .onClick(() => {
              this.load(this.path);
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

        if (this.loading) {
          Column() {
            LoadingProgress().width(40).height(40)
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.entries.length === 0) {
          Column() {
            Text('目录为空或暂不可读；文件浏览需要在线 Connector。')
              .fontSize(13)
              .fontColor('#8A8A8A')
              .textAlign(TextAlign.Center)
          }
          .layoutWeight(1)
          .width('100%')
          .padding(24)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 6 }) {
            ForEach(this.entries, (entry: FsEntryDto) => {
              ListItem() {
                Row({ space: 10 }) {
                  Text(entry.type === 'directory' ? '📁' : '📄')
                    .fontSize(16)
                  Column({ space: 2 }) {
                    Text(entry.name)
                      .fontSize(14)
                      .fontColor('#111111')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(entry.type === 'directory' ? '目录' :
                      `${this.sizeLabel(entry.size)} · 点击预览`)
                      .fontSize(11)
                      .fontColor('#8A8A8A')
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .padding(12)
                .borderRadius(8)
                .backgroundColor('#F7F7F7')
                .onClick(() => {
                  this.openEntry(entry);
                })
              }
            }, (entry: FsEntryDto) => entry.path)
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
        }
      }
      .width('100%')
      .height('100%')

      if (this.imageLoading) {
        Column({ space: 8 }) {
          LoadingProgress().width(32).height(32)
          Text('正在下载图片…').fontSize(12).fontColor('#666666')
        }
        .padding(20)
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
      }

      if (this.imagePath.length > 0) {
        Column({ space: 10 }) {
          Row() {
            Text(this.imageName)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000000')
              .layoutWeight(1)
              .maxLines(1)
            Row({ space: 8 }) {
              Button('分享')
                .height(28)
                .fontSize(12)
                .backgroundColor('#F2F2F2')
                .fontColor('#111111')
                .onClick(() => {
                  this.shareCurrentImage();
                })
              Button('关闭')
                .height(28)
                .fontSize(12)
                .backgroundColor('#F2F2F2')
                .fontColor('#111111')
                .onClick(() => {
                  this.imagePath = '';
                  this.imageName = '';
                })
            }
          }
          .width('100%')
          Image(this.imagePath)
            .width('100%')
            .layoutWeight(1)
            .objectFit(ImageFit.Contain)
        }
        .width('92%')
        .height('70%')
        .padding(16)
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
      }

      if (this.preview !== null) {
        Column({ space: 10 }) {
          Row() {
            Text(this.preview.name)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000000')
              .layoutWeight(1)
              .maxLines(1)
            Button('关闭')
              .height(28)
              .fontSize(12)
              .backgroundColor('#F2F2F2')
              .fontColor('#111111')
              .onClick(() => {
                this.preview = null;
              })
          }
          .width('100%')
          Text(`${this.sizeLabel(this.preview.size)} · ${this.preview.encoding}${this.preview.truncated ? ' · 已截断' : ''}`)
            .fontSize(11)
            .fontColor('#8A8A8A')
            .width('100%')
          Scroll() {
            if (this.preview.binary) {
              Text('二进制文件，暂不支持预览。')
                .fontSize(12)
                .fontColor('#8A8A8A')
                .width('100%')
            } else {
              Text(this.preview.content)
                .fontSize(12)
                .fontFamily('monospace')
                .fontColor('#111111')
                .width('100%')
            }
          }
          .layoutWeight(1)
          .width('100%')
        }
        .width('92%')
        .height('70%')
        .padding(16)
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .alignContent(Alignment.Center)
  }

  private async shareCurrentImage(): Promise<void> {
    if (this.imagePath.length === 0 || this.imageName.length === 0) {
      return;
    }
    try {
      const localPath: string = this.imagePath.startsWith('file://') ?
        this.imagePath.substring('file://'.length) : this.imagePath;
      const uri: string = fileUri.getUriFromPath(localPath);
      const lower: string = this.imageName.toLowerCase();
      const utdId: string = lower.endsWith('.png') ? utd.UniformDataType.PNG :
        lower.endsWith('.gif') ? utd.UniformDataType.GIF : utd.UniformDataType.JPEG;
      const data: systemShare.SharedData = new systemShare.SharedData({
        utd: utdId,
        uri: uri,
        title: this.imageName
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(data);
      controller.show(AppContextHolder.require(), {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      });
    } catch (error) {
      this.errorMessage = `分享不可用：${(error as Error).message}`;
    }
  }

  private sizeLabel(size?: number | null): string {
    if (size === null || size === undefined) {
      return '—';
    }
    if (size < 1024) {
      return `${size} B`;
    }
    if (size < 1024 * 1024) {
      return `${Math.floor(size / 1024)} KB`;
    }
    return `${(size / (1024 * 1024)).toFixed(1)} MB`;
  }
}
