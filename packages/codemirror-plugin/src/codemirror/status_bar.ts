import { EditorView, Panel, showPanel } from "@codemirror/view";
import { Path, TypeHint } from "../json/types";
import { jsonStateField } from "./json_state";

function createStatusBarPanel(view: EditorView): Panel {
  const dom = document.createElement("div");
  dom.className = "cm-status-bar";

  function updateCursor(): void {
    const pos = view.state.selection.main.head;

    const jsonState = view.state.field(jsonStateField, false);
    const validationResult = jsonState?.validationResult;
    const rootTypeHint = validationResult?.rootTypeHint;
    const nodes: Node[] = [];
    if (rootTypeHint) {
      const typeHint = findTypeHint(pos, rootTypeHint);
      if (typeHint) {
        const { pathToTypeHint } = validationResult;
        const builder = new NavigatorNodesBuilder(pathToTypeHint, view);
        builder.appendNodesForPath(typeHint.valueContext.path);
        nodes.push(...builder.nodes);
        nodes.reverse();
      }
    }
    dom.replaceChildren(...nodes);
  }

  updateCursor();

  return {
    dom,
    update(update): void {
      if (update.selectionSet) {
        updateCursor();
      }
    },
    top: false,
  };
}

export function statusBar(): ReturnType<typeof showPanel.of> {
  return showPanel.of(createStatusBarPanel);
}

function findTypeHint(pos: number, root: TypeHint): TypeHint | undefined {
  // Check if pos is within the root's segment
  const segment = root.valueContext.value.segment;
  if (pos < segment.start || pos > segment.end) {
    return undefined;
  }

  // Binary search through childHints to find a child containing pos
  let left = 0;
  let right = root.childHints.length - 1;
  let foundChild: TypeHint | undefined;

  while (left <= right) {
    const mid = Math.floor((left + right) / 2);
    const child = root.childHints[mid];
    const childSegment = child.valueContext.value.segment;

    if (pos < childSegment.start) {
      right = mid - 1;
    } else if (pos > childSegment.end) {
      left = mid + 1;
    } else {
      // pos is within this child's segment
      foundChild = child;
      break;
    }
  }

  // If we found a child containing pos, recursively search deeper
  if (foundChild) {
    const deeperHint = findTypeHint(pos, foundChild);
    return deeperHint !== undefined ? deeperHint : foundChild;
  }

  // No child contains pos, so root is the deepest match
  return root;
}

class NavigatorNodesBuilder {
  readonly nodes: Node[] = [];

  constructor(
    private readonly pathToTypeHint: ReadonlyMap<Path, TypeHint>,
    private readonly view: EditorView,
  ) {}

  appendNodesForPath(path: Path): void {
    const typeHint = this.pathToTypeHint.get(path)!;
    const pos = typeHint.valueContext.value.segment.start;
    const link = document.createElement("a");
    link.className = "cm-status-bar-link";

    link.addEventListener("click", (e) => {
      e.preventDefault();
      this.view.dispatch({
        selection: { anchor: pos, head: pos },
        scrollIntoView: true,
      });
      this.view.focus();
    });

    switch (path.kind) {
      case "root": {
        link.append("root");
        this.nodes.push(link);
        break;
      }
      case "array-item": {
        this.appendNodesForPath(path.arrayPath);
        if (path.key != null) {
          link.append(`[${path.index}|${path.key}]`);
        } else {
          link.append(`[${path.index}]`);
        }
        this.nodes.push(link);
        break;
      }
      case "field-value": {
        this.appendNodesForPath(path.structPath);
        link.append(`.${path.fieldName}`);
        this.nodes.push(link);
        break;
      }
      case "variant-value": {
        this.appendNodesForPath(path.enumPath);
        link.append(`.value("${path.variantName}")`);
        this.nodes.push(link);
        break;
      }
    }
  }
}
