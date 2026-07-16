/** content domain hataları — tipli hiyerarşi (CLAUDE.md §4). */
export class ContentError extends Error {
  constructor(
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = 'ContentError';
  }
}

export class SlugTakenError extends ContentError {
  constructor(slug: string) {
    super('slug_taken', `Bu slug zaten kullanımda: ${slug}`);
  }
}

export class InvalidSlugError extends ContentError {
  constructor() {
    super('invalid_slug', 'Slug küçük harf ve tire içermeli (ör. deep-ocean-drift).');
  }
}
