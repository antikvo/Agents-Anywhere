import { NoticeActionDto } from '../api/ProtocolDtos';

export interface InputRequestOption {
  id: string;
  label: string;
  description: string;
}

export interface InputRequestQuestion {
  id: string;
  prompt: string;
  header: string;
  multiple: boolean;
  allowCustom: boolean;
  options: InputRequestOption[];
}

export interface InputRequestForm {
  actionId: string;
  questions: InputRequestQuestion[];
}

export interface InputAnswer {
  optionIds: string[];
  customText?: string;
}

export interface InputAnswersPayload {
  answers: Record<string, InputAnswer>;
}

interface RawUiOption {
  id?: string;
  label?: string;
  description?: string;
}

interface RawUiQuestion {
  id?: string;
  prompt?: string;
  header?: string;
  multiple?: boolean;
  allowCustom?: boolean;
  options?: RawUiOption[];
}

interface RawUiSchema {
  component?: string;
  version?: number;
  questions?: RawUiQuestion[];
}

interface RawActionInput {
  uiSchema?: RawUiSchema | null;
}

function textOf(value?: string): string {
  return value === undefined || value === null ? '' : value.trim();
}

/**
 * 解析 input_request 通知里 inputRequest v1 的 uiSchema。
 * 结构对齐 Android 的 RuntimeNotice.inputRequestForm()。
 */
export function parseInputRequest(actions?: NoticeActionDto[] | null): InputRequestForm | null {
  if (actions === undefined || actions === null) {
    return null;
  }
  for (let i = 0; i < actions.length; i++) {
    const action: NoticeActionDto = actions[i];
    const input = action.input as RawActionInput | null | undefined;
    if (input === null || input === undefined) {
      continue;
    }
    const ui: RawUiSchema | null | undefined = input.uiSchema;
    if (ui === null || ui === undefined) {
      continue;
    }
    if (ui.component !== 'inputRequest' || ui.version !== 1) {
      continue;
    }
    const rawQuestions: RawUiQuestion[] = ui.questions === undefined || ui.questions === null ?
      [] : ui.questions;
    if (rawQuestions.length === 0) {
      return null;
    }
    const questions: InputRequestQuestion[] = [];
    for (let q = 0; q < rawQuestions.length; q++) {
      const raw: RawUiQuestion = rawQuestions[q];
      const id: string = textOf(raw.id);
      const prompt: string = textOf(raw.prompt);
      if (id.length === 0 || prompt.length === 0) {
        return null;
      }
      const options: InputRequestOption[] = [];
      const rawOptions: RawUiOption[] = raw.options === undefined || raw.options === null ? [] : raw.options;
      rawOptions.forEach((option: RawUiOption) => {
        const optionId: string = textOf(option.id);
        const label: string = textOf(option.label);
        if (optionId.length > 0 && label.length > 0) {
          options.push({
            id: optionId,
            label: label,
            description: textOf(option.description)
          });
        }
      });
      questions.push({
        id: id,
        prompt: prompt,
        header: textOf(raw.header),
        multiple: raw.multiple === true,
        allowCustom: raw.allowCustom !== false,
        options: options
      });
    }
    return { actionId: action.actionId, questions: questions };
  }
  return null;
}

export function buildAnswersPayload(answers: Record<string, InputAnswer>): InputAnswersPayload {
  return { answers: answers };
}
