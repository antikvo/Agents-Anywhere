import { apiUrl } from '../core/ServerUrl';
import { HttpClient } from './HttpClient';

export interface PublicAnnouncement {
  markdown: string;
  publishedAt: string;
}

interface AnnouncementResponse {
  announcement?: PublicAnnouncement | null;
}

export class AnnouncementsApi {
  private readonly client: HttpClient;

  constructor(client: HttpClient = new HttpClient()) {
    this.client = client;
  }

  async current(serverUrl: string, token: string): Promise<PublicAnnouncement | null> {
    const text: string = await this.client.requestJson(apiUrl(serverUrl, '/announcement'), {
      token: token
    });
    const response: AnnouncementResponse = JSON.parse(text) as AnnouncementResponse;
    const announcement: PublicAnnouncement | null | undefined = response.announcement;
    return announcement === undefined ? null : announcement;
  }
}
