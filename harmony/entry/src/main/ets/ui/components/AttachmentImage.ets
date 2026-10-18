import { image } from '@kit.ImageKit';
import { AttachmentsApi } from '../../api/AttachmentsApi';
import { AttachmentRefDto } from '../../api/ProtocolDtos';

/**
 * 会话附件图片：按需下载并解码为 PixelMap 后用 Image 渲染。
 * 非图片附件先占位，文件下载/打开在后续任务补齐。
 */
@Component
export struct AttachmentImage {
  serverUrl: string = '';
  token: string = '';
  sessionId: string = '';
  attachment: AttachmentRefDto | null = null;
  private api: AttachmentsApi = new AttachmentsApi();
  @State pixelMap: image.PixelMap | undefined = undefined;
  @State failed: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const attachment: AttachmentRefDto | null = this.attachment;
    if (attachment === null || this.serverUrl.length === 0 || this.token.length === 0) {
      return;
    }
    if (!attachment.mediaType.startsWith('image/')) {
      this.failed = true;
      return;
    }
    try {
      this.pixelMap = await this.api.fetchImage(this.serverUrl, this.token, this.sessionId,
        attachment.fileId);
    } catch (error) {
      this.failed = true;
    }
  }

  build() {
    if (this.pixelMap !== undefined) {
      Image(this.pixelMap)
        .width(180)
        .height(140)
        .objectFit(ImageFit.Cover)
        .borderRadius(8)
    } else {
      Row({ space: 6 }) {
        Text(this.failed ? '附件无法预览' : '图片加载中…')
          .fontSize(11)
          .fontColor('#8A8A8A')
      }
      .padding(10)
      .borderRadius(8)
      .backgroundColor('#EFEFEF')
    }
  }
}
