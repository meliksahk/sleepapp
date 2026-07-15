export class ArchetypeError extends Error {
  constructor(
    public readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = 'ArchetypeError';
  }
}

export class InvalidAnswersError extends ArchetypeError {
  constructor(detail: string) {
    super('invalid_answers', `Cevaplar geçersiz veya eksik: ${detail}`);
  }
}

export class UnsupportedMatrixVersionError extends ArchetypeError {
  constructor(got: number, expected: number) {
    super(
      'unsupported_version',
      `Soru matrisi sürümü ${got} desteklenmiyor (beklenen ${expected}).`,
    );
  }
}
