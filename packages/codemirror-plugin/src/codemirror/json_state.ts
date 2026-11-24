import {
  Extension,
  StateEffect,
  StateField,
  Transaction,
} from "@codemirror/state";
import { EditorView, ViewPlugin, ViewUpdate } from "@codemirror/view";
import { parseJsonValue } from "../json/json_parser";
import { validateSchema } from "../json/schema_validator";
import type {
  JsonParseResult,
  RecordDefinition,
  TypeDefinition,
  ValidationResult,
} from "../json/types";

export interface JsonState {
  readonly parseResult: JsonParseResult;
  readonly validationResult?: ValidationResult;
  readonly source: string;
  readonly schema: TypeDefinition;
  readonly recordIdToDefinition: { [id: string]: RecordDefinition };
}

const updateJsonState = StateEffect.define<JsonState>();

export const jsonStateField = StateField.define<JsonState | null>({
  create(): JsonState | null {
    return null;
  },
  update(value, tr): JsonState | null {
    for (const effect of tr.effects) {
      if (effect.is(updateJsonState)) {
        return effect.value;
      }
    }
    return value;
  },
});

/**
 * Ensures the JSON state is up-to-date with the current document.
 * If the state is stale or missing, triggers an immediate parse and returns the updated state.
 */
export function ensureJsonState(
  view: EditorView,
  schema: TypeDefinition,
): JsonState {
  const currentState = view.state.field(jsonStateField, false);
  const source = view.state.doc.toString();

  // If the source hasn't changed, return the current state
  if (currentState && currentState.source === source) {
    return currentState;
  }

  // Parse and validate immediately
  const parseResult = parseJsonValue(source);
  let validationResult: ValidationResult | undefined;
  if (parseResult.value) {
    validationResult = validateSchema(parseResult.value, schema);
  }

  const recordIdToDefinition = indexRecordDefinitions(schema, currentState);

  const newState: JsonState = {
    parseResult,
    validationResult,
    source,
    schema,
    recordIdToDefinition,
  };

  // Update the state if it's different
  if (!currentState || currentState !== newState) {
    view.dispatch({
      effects: updateJsonState.of(newState),
    });
  }

  return newState;
}

export function debouncedJsonParser(schema: TypeDefinition): Extension[] {
  return [
    jsonStateField,
    ViewPlugin.fromClass(
      class {
        timeout: number | null = null;
        view: EditorView;

        constructor(view: EditorView) {
          this.view = view;
          this.scheduleUpdate();
        }

        update(update: ViewUpdate): void {
          if (update.docChanged) {
            const isUndo = update.transactions.some(
              (tr) =>
                tr.annotation(Transaction.userEvent) === "undo" ||
                tr.annotation(Transaction.userEvent) === "redo",
            );
            this.scheduleUpdate(isUndo ? "from-undo" : undefined);
          }
        }

        scheduleUpdate(fromUndo?: "from-undo"): void {
          if (this.timeout !== null) {
            clearTimeout(this.timeout);
          }
          this.timeout = window.setTimeout(() => {
            this.parseJson(fromUndo);
            this.timeout = null;
          }, 200);
        }

        parseJson(fromUndo: "from-undo" | undefined): void {
          const source = this.view.state.doc.toString();
          const parseResult = parseJsonValue(source);

          let validationResult: ValidationResult | undefined;
          if (parseResult.value) {
            validationResult = validateSchema(parseResult.value, schema);
          }

          const cursorInsideEdit = (): boolean => {
            const cursorPos = this.view.state.selection.main.head;
            return parseResult.edits.some(
              (edit) =>
                edit.segment.start <= cursorPos &&
                cursorPos <= edit.segment.end,
            );
          };

          // Apply edits if all these conditions are satisfied:
          //   - no error
          //   - the cursor is not inside any of the edited segments, to avoid
          //       disrupting the user while they're typing
          //   - the update is not triggered by an undo operation
          if (
            !fromUndo &&
            parseResult.edits.length &&
            parseResult.errors.length <= 0 &&
            !cursorInsideEdit()
          ) {
            const changes = parseResult.edits.map((edit) => ({
              from: edit.segment.start,
              to: edit.segment.end,
              insert: edit.replacement,
            }));

            const oldState = this.view.state.field(jsonStateField, false);
            const recordIdToDefinition = indexRecordDefinitions(
              schema,
              oldState,
            );

            this.view.dispatch({
              changes,
              effects: updateJsonState.of({
                parseResult,
                validationResult,
                source,
                schema,
                recordIdToDefinition,
              }),
              scrollIntoView: true,
            });
          } else {
            const oldState = this.view.state.field(jsonStateField, false);
            const recordIdToDefinition = indexRecordDefinitions(
              schema,
              oldState,
            );

            this.view.dispatch({
              effects: updateJsonState.of({
                parseResult,
                validationResult,
                source,
                schema,
                recordIdToDefinition,
              }),
            });
          }
        }

        destroy(): void {
          if (this.timeout !== null) {
            clearTimeout(this.timeout);
          }
        }
      },
    ),
  ];
}

function indexRecordDefinitions(
  schema: TypeDefinition,
  oldState: JsonState | null | undefined,
): {
  [id: string]: RecordDefinition;
} {
  if (schema === oldState?.schema) {
    return oldState.recordIdToDefinition;
  }
  const idToRecordDef: { [id: string]: RecordDefinition } = {};
  for (const recordDef of schema.records) {
    idToRecordDef[recordDef.id] = recordDef;
  }
  return idToRecordDef;
}
