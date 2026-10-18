import { LengthMetrics } from '@kit.ArkUI';
import { InputAnswer, InputAnswersPayload, InputRequestForm, InputRequestQuestion, InputRequestOption } from '../../model/InputRequest';

/**
 * input_request 表单：单选/多选 + 自定义文本，提交时组装 {answers:{qid:{optionIds,customText?}}}。
 */
@Component
export struct InputRequestCard {
  form: InputRequestForm = { actionId: '', questions: [] };
  submitting: boolean = false;
  onSubmit: (actionId: string, payload: InputAnswersPayload) => void = () => {
  };
  @State selected: string[][] = [];
  @State customText: string[] = [];

  aboutToAppear(): void {
    const selected: string[][] = [];
    const custom: string[] = [];
    this.form.questions.forEach(() => {
      selected.push([]);
      custom.push('');
    });
    this.selected = selected;
    this.customText = custom;
  }

  private toggle(question: InputRequestQuestion, index: number, optionId: string): void {
    const current: string[] = this.selected[index];
    let next: string[] = [];
    const active: boolean = current.indexOf(optionId) >= 0;
    if (question.multiple) {
      if (active) {
        current.forEach((id: string) => {
          if (id !== optionId) {
            next.push(id);
          }
        });
      } else {
        next = current.concat([optionId]);
      }
    } else {
      next = active ? [] : [optionId];
    }
    const updated: string[][] = [];
    for (let i = 0; i < this.selected.length; i++) {
      updated.push(i === index ? next : this.selected[i]);
    }
    this.selected = updated;
  }

  private setCustom(index: number, value: string): void {
    const updated: string[] = [];
    for (let i = 0; i < this.customText.length; i++) {
      updated.push(i === index ? value : this.customText[i]);
    }
    this.customText = updated;
  }

  private isComplete(): boolean {
    for (let i = 0; i < this.form.questions.length; i++) {
      const ids: string[] = this.selected[i];
      const custom: string = this.customText[i].trim();
      if (ids.length === 0 && custom.length === 0) {
        return false;
      }
      if (!this.form.questions[i].multiple && ids.length > 1) {
        return false;
      }
    }
    return true;
  }

  private submit(): void {
    if (!this.isComplete() || this.submitting) {
      return;
    }
    const answers: Record<string, InputAnswer> = {};
    this.form.questions.forEach((question: InputRequestQuestion, index: number) => {
      const answer: InputAnswer = { optionIds: this.selected[index] };
      const custom: string = this.customText[index].trim();
      if (custom.length > 0) {
        answer.customText = custom;
      }
      answers[question.id] = answer;
    });
    const payload: InputAnswersPayload = { answers: answers };
    this.onSubmit(this.form.actionId, payload);
  }

  build() {
    Column({ space: 10 }) {
      ForEach(this.form.questions, (question: InputRequestQuestion, index: number) => {
        Column({ space: 6 }) {
          if (question.header.length > 0) {
            Text(question.header)
              .fontSize(11)
              .fontColor('#8A8A8A')
              .width('100%')
          }
          Text(question.prompt)
            .fontSize(13)
            .fontColor('#111111')
            .width('100%')
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(6) } }) {
            ForEach(question.options, (option: InputRequestOption) => {
              Button(option.label)
                .height(30)
                .fontSize(12)
                .backgroundColor((this.selected[index] ?? []).indexOf(option.id) >= 0 ? '#000000' : '#EAEAEA')
                .fontColor((this.selected[index] ?? []).indexOf(option.id) >= 0 ? '#FFFFFF' : '#333333')
                .onClick(() => {
                  this.toggle(question, index, option.id);
                })
            }, (option: InputRequestOption) => option.id)
          }
          .width('100%')

          if (question.allowCustom) {
            TextInput({ placeholder: '其他（可选）', text: this.customText[index] ?? '' })
              .height(36)
              .fontSize(13)
              .backgroundColor('#FFFFFF')
              .borderRadius(8)
              .onChange((value: string) => {
                this.setCustom(index, value);
              })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }, (question: InputRequestQuestion) => question.id)

      Button(this.submitting ? '提交中…' : '提交')
        .height(34)
        .fontSize(13)
        .enabled(!this.submitting && this.isComplete())
        .onClick(() => {
          this.submit();
        })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
