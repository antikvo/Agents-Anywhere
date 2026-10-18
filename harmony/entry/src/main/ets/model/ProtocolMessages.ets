/**
 * 解析用户侧协议消息（Codex question 回填等）。
 * 样例：<send_user_message_question_reply> [{"question":"…","answer":"…"}] </send_user_message_question_reply>
 */
export interface QuestionAnswer {
  question: string;
  answer: string;
}

interface RawQuestionAnswer {
  question?: string;
  answer?: string;
}

const REPLY_TAG: string = '<send_user_message_question_reply>';

export function parseQuestionReply(text: string): QuestionAnswer[] | null {
  const trimmed: string = text.trim();
  if (!trimmed.startsWith(REPLY_TAG)) {
    return null;
  }
  const endTag: number = trimmed.indexOf('</send_user_message_question_reply>');
  const payload: string = endTag > 0 ?
    trimmed.substring(REPLY_TAG.length, endTag).trim() :
    trimmed.substring(REPLY_TAG.length).trim();
  try {
    const parsed: RawQuestionAnswer[] = JSON.parse(payload) as RawQuestionAnswer[];
    if (!Array.isArray(parsed)) {
      return null;
    }
    const items: QuestionAnswer[] = [];
    parsed.forEach((raw: RawQuestionAnswer) => {
      const question: string = raw.question === undefined || raw.question === null ? '' : raw.question;
      const answer: string = raw.answer === undefined || raw.answer === null ? '' : raw.answer;
      if (question.length > 0 || answer.length > 0) {
        items.push({ question: question, answer: answer });
      }
    });
    return items.length > 0 ? items : null;
  } catch (error) {
    return null;
  }
}
