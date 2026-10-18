/**
 * 轻量 Markdown 解析：块级结构 + 行内强调。
 *
 * 只覆盖 Agent 输出里最常见的子集：
 * 标题、段落、无序/有序列表、引用、分割线、围栏代码块、行内 code / 粗体 / 斜体 / 链接。
 * 表格、图片、嵌套列表在后续任务补齐。
 */

export enum MarkdownBlockKind {
  Paragraph = 'paragraph',
  Heading = 'heading',
  Code = 'code',
  ListItem = 'list_item',
  Quote = 'quote',
  Divider = 'divider',
  Table = 'table',
  Image = 'image'
}

export interface MarkdownBlock {
  kind: MarkdownBlockKind;
  text: string;
  level: number;
  language: string;
  ordered: boolean;
  index: number;
  table?: string[][];
  url?: string;
}

export enum InlineStyle {
  Plain = 'plain',
  Bold = 'bold',
  Italic = 'italic',
  Code = 'code',
  Link = 'link'
}

export interface InlineSpan {
  text: string;
  style: InlineStyle;
}

function isTableRow(line: string): boolean {
  const trimmed: string = line.trim();
  return trimmed.startsWith('|') && trimmed.indexOf('|', 1) > 0;
}

function splitTableRow(line: string): string[] {
  let text: string = line.trim();
  if (text.startsWith('|')) {
    text = text.substring(1);
  }
  if (text.endsWith('|')) {
    text = text.substring(0, text.length - 1);
  }
  const cells: string[] = text.split('|');
  return cells.map((cell: string) => cell.trim());
}

function isTableSeparator(cells: string[]): boolean {
  if (cells.length === 0) {
    return false;
  }
  for (let i = 0; i < cells.length; i++) {
    const cell: string = cells[i].replace(/:/g, '');
    if (cell.length === 0) {
      return false;
    }
    for (let j = 0; j < cell.length; j++) {
      if (cell.charAt(j) !== '-') {
        return false;
      }
    }
  }
  return true;
}

function leadingSpaces(line: string): number {
  let count: number = 0;
  while (count < line.length && line.charAt(count) === ' ') {
    count++;
  }
  return count;
}

function listItem(line: string): MarkdownBlock | null {
  const trimmed: string = line.trim();
  const indent: number = leadingSpaces(line);
  if (trimmed.startsWith('- ') || trimmed.startsWith('* ') || trimmed.startsWith('+ ')) {
    return {
      kind: MarkdownBlockKind.ListItem,
      text: trimmed.substring(2).trim(),
      level: 0,
      language: '',
      ordered: false,
      index: 0
    };
  }
  const dot: number = trimmed.indexOf('. ');
  if (dot > 0) {
    const prefix: string = trimmed.substring(0, dot);
    let numeric: boolean = true;
    for (let i = 0; i < prefix.length; i++) {
      const code: number = prefix.charCodeAt(i);
      if (code < 48 || code > 57) {
        numeric = false;
        break;
      }
    }
    if (numeric) {
      return {
        kind: MarkdownBlockKind.ListItem,
        text: trimmed.substring(dot + 2).trim(),
        level: Math.floor(indent / 2),
        language: '',
        ordered: true,
        index: Number(prefix),
        table: []
      };
    }
  }
  return null;
}

function headingLevel(line: string): number {
  let level: number = 0;
  while (level < line.length && line.charAt(level) === '#') {
    level++;
  }
  if (level > 0 && level <= 6 && level < line.length && line.charAt(level) === ' ') {
    return level;
  }
  return 0;
}

export function parseMarkdown(source: string): MarkdownBlock[] {
  const lines: string[] = source.split('\n');
  const blocks: MarkdownBlock[] = [];
  let index: number = 0;
  while (index < lines.length) {
    const raw: string = lines[index];
    const trimmed: string = raw.trim();
    if (trimmed.length === 0) {
      index++;
      continue;
    }
    if (trimmed.startsWith('```')) {
      const language: string = trimmed.substring(3).trim();
      const codeLines: string[] = [];
      index++;
      while (index < lines.length && !lines[index].trim().startsWith('```')) {
        codeLines.push(lines[index]);
        index++;
      }
      if (index < lines.length) {
        index++;
      }
      blocks.push({
        kind: MarkdownBlockKind.Code,
        text: codeLines.join('\n'),
        level: 0,
        language: language,
        ordered: false,
        index: 0,
        table: []
      });
      continue;
    }
    const level: number = headingLevel(trimmed);
    if (level > 0) {
      blocks.push({
        kind: MarkdownBlockKind.Heading,
        text: trimmed.substring(level + 1).trim(),
        level: level,
        language: '',
        ordered: false,
        index: 0,
        table: []
      });
      index++;
      continue;
    }
    if (trimmed === '---' || trimmed === '***' || trimmed === '___') {
      blocks.push({
        kind: MarkdownBlockKind.Divider,
        text: '',
        level: 0,
        language: '',
        ordered: false,
        index: 0,
        table: []
      });
      index++;
      continue;
    }
    if (trimmed.startsWith('> ')) {
      blocks.push({
        kind: MarkdownBlockKind.Quote,
        text: trimmed.substring(2).trim(),
        level: 0,
        language: '',
        ordered: false,
        index: 0,
        table: []
      });
      index++;
      continue;
    }
    if (isTableRow(raw)) {
      const rows: string[][] = [];
      let cursor: number = index;
      while (cursor < lines.length && isTableRow(lines[cursor])) {
        const cells: string[] = splitTableRow(lines[cursor]);
        if (!isTableSeparator(cells)) {
          rows.push(cells);
        }
        cursor++;
      }
      if (rows.length > 0) {
        blocks.push({
          kind: MarkdownBlockKind.Table,
          text: '',
          level: 0,
          language: '',
          ordered: false,
          index: 0,
          table: rows
        });
      }
      index = cursor;
      continue;
    }
    const item: MarkdownBlock | null = listItem(raw);
    if (item !== null) {
      blocks.push(item);
      index++;
      continue;
    }
    if (trimmed.startsWith('![')) {
      const altEnd: number = trimmed.indexOf('](', 2);
      const urlEnd: number = altEnd > 0 ? trimmed.indexOf(')', altEnd + 2) : -1;
      if (altEnd > 0 && urlEnd > 0) {
        blocks.push({
          kind: MarkdownBlockKind.Image,
          text: trimmed.substring(2, altEnd),
          level: 0,
          language: '',
          ordered: false,
          index: 0,
          table: [],
          url: trimmed.substring(altEnd + 2, urlEnd).trim()
        });
        index++;
        continue;
      }
    }
    const paragraph: string[] = [trimmed];
    index++;
    while (index < lines.length) {
      const next: string = lines[index].trim();
      if (next.length === 0 || next.startsWith('```') || headingLevel(next) > 0 ||
        next.startsWith('> ') || next.startsWith('- ') || next.startsWith('* ') ||
        next.startsWith('+ ') || listItem(next) !== null || next === '---' || isTableRow(next)) {
        break;
      }
      paragraph.push(next);
      index++;
    }
    blocks.push({
      kind: MarkdownBlockKind.Paragraph,
      text: paragraph.join(' '),
      level: 0,
      language: '',
      ordered: false,
      index: 0
    });
  }
  return blocks;
}

export function parseInline(text: string): InlineSpan[] {
  const spans: InlineSpan[] = [];
  let plain: string = '';
  let index: number = 0;

  const flushPlain = (): void => {
    if (plain.length > 0) {
      spans.push({ text: plain, style: InlineStyle.Plain });
      plain = '';
    }
  };

  while (index < text.length) {
    const rest: string = text.substring(index);
    if (rest.startsWith('`')) {
      const end: number = rest.indexOf('`', 1);
      if (end > 0) {
        flushPlain();
        spans.push({ text: rest.substring(1, end), style: InlineStyle.Code });
        index += end + 1;
        continue;
      }
    }
    if (rest.startsWith('**')) {
      const end: number = rest.indexOf('**', 2);
      if (end > 0) {
        flushPlain();
        spans.push({ text: rest.substring(2, end), style: InlineStyle.Bold });
        index += end + 2;
        continue;
      }
    }
    if (rest.startsWith('[')) {
      const labelEnd: number = rest.indexOf('](', 1);
      const urlEnd: number = labelEnd > 0 ? rest.indexOf(')', labelEnd + 2) : -1;
      if (labelEnd > 0 && urlEnd > 0) {
        flushPlain();
        spans.push({ text: rest.substring(1, labelEnd), style: InlineStyle.Link });
        index += urlEnd + 1;
        continue;
      }
    }
    plain += text.charAt(index);
    index++;
  }
  flushPlain();
  return spans;
}
