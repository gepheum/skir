/**
 * A single moment in time represented in a platform-independent format, with a
 * precision of one millisecond.
 *
 * A `Timestamp` object can represent a maximum of ±8,640,000,000,000,000
 * milliseconds, or ±100,000,000 (one hundred million) days, relative to the
 * Unix epoch. This is the range from April 20, 271821 BC to September 13,
 * 275760 AD.
 *
 * Unlike the Javascript built-in `Date` type, a `Timestamp` is immutable.
 * Like a `Date`, a `Timestamp` object does not contain a timezone.
 */
export class Timestamp {
  /**
   * Returns a `Timestamp` representing the same moment in time as the given
   * Javascript `Date` object.
   *
   * @throws if the given `Date` object has a timestamp value of NaN
   */
  static from(date: Date): Timestamp {
    return this.fromUnixMillis(date.getTime());
  }

  /**
   * Creates a `Timestamp` object from a number of milliseconds from the Unix
   * epoch.
   *
   * If the given number if outside the valid range (±8,640,000,000,000,000),
   * this function will return `Timestamp.MAX` or `Timestamp.MIN` depending on
   * the sign of the number.
   *
   * @throws if the given number is NaN
   */
  static fromUnixMillis(unixMillis: number): Timestamp {
    if (unixMillis <= this.MIN.unixMillis) {
      return Timestamp.MIN;
    } else if (unixMillis < Timestamp.MAX.unixMillis) {
      return new Timestamp(Math.round(unixMillis));
    } else if (Number.isNaN(unixMillis)) {
      throw new Error("Cannot construct Timestamp from NaN");
    } else {
      return Timestamp.MAX;
    }
  }

  /**
   * Creates a `Timestamp` object from a number of seconds from the Unix epoch.
   *
   * If the given number if outside the valid range (±8,640,000,000,000), this
   * function will return `Timestamp.MAX` or `Timestamp.MIN` depending on the
   * sign of the number.
   *
   * @throws if the given number is NaN
   */
  static fromUnixSeconds(unixSeconds: number): Timestamp {
    return this.fromUnixMillis(unixSeconds * 1000);
  }

  /**
   * Parses a date in the date time string format.
   *
   * @throws if the given string is not a date in the date time string format
   * @see https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-date-time-string-format
   */
  static parse(date: string): Timestamp {
    return this.fromUnixMillis(Date.parse(date));
  }

  /** Returns a `Timestamp` representing the current moment in time. */
  static now(): Timestamp {
    return this.fromUnixMillis(Date.now());
  }

  /** Thursday, 1 January 1970. */
  static readonly UNIX_EPOCH = new Timestamp(0);

  /**
   * Earliest moment in time representable as a `Timestamp`, namely April 20,
   * 271821 BC.
   *
   * @see https://262.ecma-international.org/5.1/#sec-15.9.1.1
   */
  static readonly MIN = new Timestamp(-8640000000000000);

  /**
   * Latest moment in time representable as a `Timestamp`, namely September 13,
   * 275760 AD.
   *
   * @see https://262.ecma-international.org/5.1/#sec-15.9.1.1
   */
  static readonly MAX = new Timestamp(8640000000000000);

  private constructor(
    /** Number of milliseconds ellapsed since the Unix epoch. */
    readonly unixMillis: number,
  ) {
    Object.freeze(this);
  }

  /** Number of seconds ellapsed since the Unix epoch. */
  get unixSeconds(): number {
    return this.unixMillis / 1000.0;
  }

  /**
   * Returns a `Date` object representing the same moment in time as this
   * `Timestamp`.
   */
  toDate(): Date {
    return new Date(this.unixMillis);
  }

  toString(): string {
    return this.toDate().toISOString();
  }
}
