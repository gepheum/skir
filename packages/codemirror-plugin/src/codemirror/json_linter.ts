import { Diagnostic } from "@codemirror/lint";
import { EditorView } from "@codemirror/view";
import { makeJsonTemplate } from "../json/to_json";
import { Hint, JsonError, JsonLiteral, TypeHint } from "../json/types";
import { jsonStateField } from "./json_state";

export function jsonLinter(
  editable: "editable" | "read-only",
): (view: EditorView) => Diagnostic[] {
  function lintJson(view: EditorView): Diagnostic[] {
    const jsonState = view.state.field(jsonStateField, false);
    if (!jsonState) {
      return [];
    }

    const parseResult = jsonState.parseResult;
    if (parseResult.errors.length) {
      return parseResult.errors.map(errorToDiagnostic);
    }

    if (!jsonState.validationResult) {
      return [];
    }

    const { errors, hints } = jsonState.validationResult;
    return errors
      .map(errorToDiagnostic)
      .concat(hints.map((hint) => hintToDiagnostic(hint, editable)));
  }

  return lintJson;
}

function errorToDiagnostic(error: JsonError): Diagnostic {
  return {
    from: error.segment.start,
    to: error.segment.end,
    message: error.message,
    severity: "error",
    renderMessage: (): Node => {
      const wrapper = document.createElement("div");
      wrapper.className = "cm-diagnostic-wrapper";
      wrapper.textContent = error.message;
      return wrapper;
    },
  };
}

function getStringControlRows(
  view: EditorView,
  typeHint: TypeHint,
  value: JsonLiteral,
  editable: "editable" | "read-only",
): HTMLDivElement[] {
  const headerRow = document.createElement("div");
  headerRow.textContent = typeHint.message as string;

  const jsonCode = value.jsonCode;
  const parsedValue = JSON.parse(jsonCode) as string;

  const controlsRow = document.createElement("div");
  controlsRow.className = "cm-diagnostic-controls";

  const label = document.createElement("span");
  // label.className = "cm-diagnostic-label";
  label.textContent = "Value:";

  const textarea = document.createElement("textarea");
  textarea.className = "cm-diagnostic-textarea";
  textarea.value = parsedValue;
  textarea.rows = 1;
  const isReadOnly = editable === "read-only";
  textarea.readOnly = isReadOnly;

  textarea.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey && !isReadOnly) {
      e.preventDefault();
      const newValue = textarea.value;
      const newJsonString = JSON.stringify(newValue);

      view.dispatch({
        changes: {
          from: typeHint.segment.start,
          to: typeHint.segment.end,
          insert: newJsonString,
        },
      });
    }
  });

  controlsRow.appendChild(label);
  controlsRow.appendChild(textarea);

  return [headerRow, controlsRow];
}

function getTimestampControlRows(
  view: EditorView,
  typeHint: TypeHint,
): HTMLDivElement[] {
  const headerRow = document.createElement("div");
  headerRow.textContent = typeHint.message as string;

  let unixMillis: number | undefined;
  {
    const value = typeHint.valueContext!.value;
    if (value.kind === "object") {
      const unixMillisKv = value.keyValues["unix_millis"];
      if (
        unixMillisKv &&
        unixMillisKv.value.kind === "literal" &&
        unixMillisKv.value.type === "number"
      ) {
        unixMillis = JSON.parse(unixMillisKv.value.jsonCode) as number;
        if (unixMillis < -8640000000000000 || 8640000000000000 < unixMillis) {
          unixMillis = undefined;
        }
      }
    }
  }

  // Row 1: unix_millis input
  const row1 = document.createElement("div");
  row1.className = "cm-diagnostic-controls";

  const label1 = document.createElement("span");
  label1.className = "cm-diagnostic-label";
  label1.textContent = "unix_millis:";

  const field1 = document.createElement("div");
  field1.className = "cm-timestamp-field";

  const unixMillisInput = document.createElement("input");
  unixMillisInput.type = "text";
  unixMillisInput.className = "cm-diagnostic-input";
  unixMillisInput.value = unixMillis !== undefined ? String(unixMillis) : "";

  const error1 = document.createElement("div");
  error1.className = "cm-diagnostic-error-message";
  error1.style.display = "none";

  field1.appendChild(unixMillisInput);
  field1.appendChild(error1);
  row1.appendChild(label1);
  row1.appendChild(field1);

  // Row 2: ISO 8601 date string input
  const row2 = document.createElement("div");
  row2.className = "cm-diagnostic-controls";

  const label2 = document.createElement("span");
  label2.className = "cm-diagnostic-label";
  label2.textContent = "ISO 8601:";

  const field2 = document.createElement("div");
  field2.className = "cm-timestamp-field";

  const isoInput = document.createElement("input");
  isoInput.type = "text";
  isoInput.className = "cm-diagnostic-input";
  if (unixMillis !== undefined) {
    isoInput.value = new Date(unixMillis).toISOString();
  }

  const error2 = document.createElement("div");
  error2.className = "cm-diagnostic-error-message";
  error2.style.display = "none";

  field2.appendChild(isoInput);
  field2.appendChild(error2);
  row2.appendChild(label2);
  row2.appendChild(field2);

  // Row 3: Now button
  const row3 = document.createElement("div");
  row3.className = "cm-diagnostic-controls";

  const nowButton = document.createElement("button");
  nowButton.className = "cm-diagnostic-button";
  nowButton.textContent = "Now";

  row3.appendChild(nowButton);

  // Helper function to update the editor
  const updateEditor = (millis: number, formatted: string): void => {
    const value = typeHint.valueContext!.value;

    // Check if both keys exist in the object
    if (value.kind === "object") {
      const unixMillisKv = value.keyValues["unix_millis"];
      const formattedKv = value.keyValues["formatted"];

      if (unixMillisKv && formattedKv) {
        // Update both values individually
        view.dispatch({
          changes: [
            {
              from: unixMillisKv.value.segment.start,
              to: unixMillisKv.value.segment.end,
              insert: String(millis),
            },
            {
              from: formattedKv.value.segment.start,
              to: formattedKv.value.segment.end,
              insert: JSON.stringify(formatted),
            },
          ],
        });

        return;
      }
    }

    // Default behavior: replace the whole object
    const newJsonString = `{"unix_millis": ${millis}, "formatted": "${formatted}"}`;

    const segment = typeHint.valueContext!.value.segment;
    view.dispatch({
      changes: {
        from: segment.start,
        to: segment.end,
        insert: newJsonString,
      },
    });
  };

  // Enter key handler for unix_millis input
  unixMillisInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      const value = unixMillisInput.value.trim();
      const millis = Number(value);

      // Validate
      if (value === "" || isNaN(millis) || !Number.isInteger(millis)) {
        error1.textContent = "Must be an integer";
        error1.style.display = "block";
        return;
      }

      if (millis < -8640000000000000 || millis > 8640000000000000) {
        error1.textContent = "Timestamp out of range";
        error1.style.display = "block";
        return;
      }

      error1.style.display = "none";
      error2.style.display = "none";

      // Update ISO field and editor
      const formatted = new Date(millis).toISOString();
      isoInput.value = formatted;
      updateEditor(millis, formatted);
    }
  });

  // Enter key handler for ISO 8601 input
  isoInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      const value = isoInput.value.trim();
      const millis = Date.parse(value);

      // Validate
      if (isNaN(millis)) {
        error2.textContent = "Invalid ISO 8601 date string";
        error2.style.display = "block";
        return;
      }

      error1.style.display = "none";
      error2.style.display = "none";

      // Update unix_millis field and editor
      const formatted = new Date(millis).toISOString();
      unixMillisInput.value = String(millis);
      updateEditor(millis, formatted);
    }
  });

  // Now button handler
  nowButton.addEventListener("click", () => {
    const now = Date.now();
    const formatted = new Date(now).toISOString();

    unixMillisInput.value = String(now);
    isoInput.value = formatted;
    error1.style.display = "none";
    error2.style.display = "none";

    updateEditor(now, formatted);
  });

  const controlsRow = document.createElement("div");
  controlsRow.appendChild(row1);
  controlsRow.appendChild(row2);
  controlsRow.appendChild(row3);

  return [headerRow, controlsRow];
}

function getEnumDropdown(
  view: EditorView,
  typeHint: TypeHint,
  enumDefinition: NonNullable<TypeHint["enumDefinition"]>,
): HTMLDivElement {
  const controlsRow = document.createElement("div");
  controlsRow.className = "cm-diagnostic-controls";

  const label = document.createElement("span");
  label.className = "cm-diagnostic-label";
  label.textContent = "Variant:";

  const select = document.createElement("select");
  select.className = "cm-diagnostic-input";

  {
    // Add the UNKNOWN variant
    const option = document.createElement("option");
    option.value = "UNKNOWN";
    option.textContent = "UNKNOWN";
    select.appendChild(option);
  }
  for (const variant of enumDefinition.variants) {
    const option = document.createElement("option");
    option.value = variant.name;
    option.textContent = variant.name;
    select.appendChild(option);
  }

  const currentValue = typeHint.valueContext?.value;
  if (
    currentValue &&
    currentValue.kind === "literal" &&
    currentValue.type === "string"
  ) {
    try {
      select.value = JSON.parse(currentValue.jsonCode) as string;
    } catch {
      // Ignore invalid value and keep the default selection.
    }
  }

  select.addEventListener("change", () => {
    const variant = enumDefinition.variants.find(
      (variant) => variant.name === select.value,
    )!;
    let newJsonString: string;
    if (variant.type) {
      const jsonState = view.state.field(jsonStateField, false)!;
      const valueJson = makeJsonTemplate(
        variant.type,
        jsonState.recordIdToDefinition,
      );
      newJsonString = JSON.stringify(
        {
          kind: variant.name,
          value: valueJson,
        },
        null,
        2,
      ).replaceAll("\n", "\n" + " ".repeat(typeHint.valueContext.value.indent));
    } else {
      newJsonString = JSON.stringify(variant.name);
    }
    view.dispatch({
      changes: {
        from: typeHint.segment.start,
        to: typeHint.segment.end,
        insert: newJsonString,
      },
    });
  });

  controlsRow.appendChild(label);
  controlsRow.appendChild(select);
  return controlsRow;
}

function hintToDiagnostic(
  typeHint: Hint,
  editable: "editable" | "read-only",
): Diagnostic {
  const { message } = typeHint;
  return {
    from: typeHint.segment.start,
    to: typeHint.segment.end,
    message: "",
    severity: "info",
    renderMessage: (view): Node => {
      const wrapper = document.createElement("div");
      wrapper.className = "cm-diagnostic-wrapper";

      let rows: HTMLDivElement[];
      if (
        (message === "string" || message === "string?") &&
        typeHint.valueContext &&
        typeHint.valueContext.value.kind === "literal" &&
        typeHint.valueContext.value.type === "string"
      ) {
        // Render a string editing control for string hints.
        rows = getStringControlRows(
          view,
          typeHint,
          typeHint.valueContext.value,
          editable,
        );
      } else if (
        (message === "timestamp" || message === "timestamp?") &&
        typeHint.valueContext &&
        typeHint.valueContext.value.kind === "object" &&
        editable === "editable"
      ) {
        // Render a timestamp editing control for timestamp hints.
        rows = getTimestampControlRows(view, typeHint);
      } else {
        // Display the message.
        const pieces = typeof message === "string" ? [message] : message;
        rows = pieces.map((piece) => {
          const row = document.createElement("div");
          row.textContent = piece;
          return row;
        });
        if (
          typeHint.valueContext &&
          typeHint.enumDefinition &&
          editable === "editable"
        ) {
          // Render a dropdown for selecting a different variant.
          rows.push(getEnumDropdown(view, typeHint, typeHint.enumDefinition));
        }
      }

      for (const row of rows) {
        row.classList.add("diagnostic-row");
        wrapper.appendChild(row);
      }

      return wrapper;
    },
    markClass: "",
  };
}
