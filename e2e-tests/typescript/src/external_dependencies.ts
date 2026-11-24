import { describe, it } from "mocha";
import { Quest } from "../skirout/@gepheum/skir-fantasy-game-example/fantasy_game.js";
import { QuestCollection } from "../skirout/quest_collection.js";

describe("external dependencies", () => {
  it("access", () => {
    [Quest, QuestCollection];
  });
});
