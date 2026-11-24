#!/usr/bin/env node
// Starts a geometry service at http://localhost:8787/geometry
//
// Run with:
//   npm run server
//
// This service demonstrates Skir's type system features through 5 methods:
// 1. CalculateMetrics - Basic shape analysis with enums
// 2. AnalyzeTriangle - Triangle-specific properties
// 3. BatchAnalyze - Working with arrays and keyed arrays
// 4. TransformShape - Geometric transformations
// 5. FindLargestShape - Collection operations

import express from "express";
import open from "open";
import * as $ from "skir-client";
import { Service, installServiceOnExpressApp } from "skir-client";
import {
  DrawableShape,
  MeasurementUnit,
  Point,
  Shape,
  ShapeMetrics,
  TriangleInfo,
} from "../skirout/geometry.js";
import {
  AnalyzeTriangle,
  AnalyzeTriangleRequest,
  AnalyzeTriangleResponse,
  BatchAnalyze,
  BatchAnalyzeRequest,
  BatchAnalyzeResponse,
  CalculateMetrics,
  CalculateMetricsRequest,
  CalculateMetricsResponse,
  FindLargestShape,
  FindLargestShapeRequest,
  FindLargestShapeResponse,
  ShapeAnalysisResult,
  TransformShape,
  TransformShapeRequest,
  TransformShapeResponse,
} from "../skirout/service.js";

const app = express();
const port = 8787;

// CORS middleware
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  res.header("Access-Control-Allow-Headers", "*");
  if (req.method === "OPTIONS") {
    res.sendStatus(200);
  } else {
    next();
  }
});

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

function distance(p1: Point.OrMutable, p2: Point.OrMutable): number {
  const dx = p1.x - p2.x;
  const dy = p1.y - p2.y;
  return Math.sqrt(dx * dx + dy * dy);
}

function metersToFeet(meters: number): number {
  return meters * 3.28084;
}

function squareMetersToSquareFeet(sqMeters: number): number {
  return sqMeters * 10.7639;
}

function convertDistance(value: number, unit: MeasurementUnit): number {
  const unitView = unit.union;
  if (unitView.kind === "FEET") {
    return metersToFeet(value);
  } else if (unitView.kind === "custom") {
    return value * unitView.value;
  }
  return value; // METERS
}

function convertArea(value: number, unit: MeasurementUnit): number {
  const unitView = unit.union;
  if (unitView.kind === "FEET") {
    return squareMetersToSquareFeet(value);
  } else if (unitView.kind === "custom") {
    const factor = unitView.value;
    return value * factor * factor;
  }
  return value; // METERS
}

function calculateTriangleArea(a: number, b: number, c: number): number {
  const s = (a + b + c) / 2;
  return Math.sqrt(s * (s - a) * (s - b) * (s - c));
}

function isRightTriangle(a: number, b: number, c: number): boolean {
  const sides = [a, b, c].sort((x, y) => x - y);
  const [side1, side2, hypotenuse] = sides;
  const epsilon = 0.0001;
  return (
    Math.abs(side1 * side1 + side2 * side2 - hypotenuse * hypotenuse) < epsilon
  );
}

function calculatePolygonArea(points: ReadonlyArray<Point.OrMutable>): number {
  if (points.length < 3) return 0;
  let area = 0;
  const n = points.length;
  for (let i = 0; i < n; i++) {
    const j = (i + 1) % n;
    area += points[i].x * points[j].y;
    area -= points[j].x * points[i].y;
  }
  return Math.abs(area) / 2;
}

function calculateCentroid(points: ReadonlyArray<Point.OrMutable>): Point {
  let sumX = 0,
    sumY = 0;
  for (const p of points) {
    sumX += p.x;
    sumY += p.y;
  }
  return Point.create({
    x: sumX / points.length,
    y: sumY / points.length,
  });
}

function calculateBoundingBox(
  points: ReadonlyArray<Point.OrMutable>,
): ShapeMetrics.BoundingBox {
  if (points.length === 0) {
    return ShapeMetrics.BoundingBox.create({
      minX: 0,
      minY: 0,
      maxX: 0,
      maxY: 0,
    });
  }
  let minX = points[0].x,
    maxX = points[0].x;
  let minY = points[0].y,
    maxY = points[0].y;
  for (const p of points) {
    minX = Math.min(minX, p.x);
    maxX = Math.max(maxX, p.x);
    minY = Math.min(minY, p.y);
    maxY = Math.max(maxY, p.y);
  }
  return ShapeMetrics.BoundingBox.create({ minX, minY, maxX, maxY });
}

function rotatePoint(p: Point.OrMutable, angle: number): Point {
  const cos = Math.cos(angle);
  const sin = Math.sin(angle);
  return Point.create({
    x: p.x * cos - p.y * sin,
    y: p.x * sin + p.y * cos,
  });
}

function scalePoint(p: Point.OrMutable, scale: number): Point {
  return Point.create({
    x: p.x * scale,
    y: p.y * scale,
  });
}

function translatePoint(p: Point.OrMutable, offset: Point.OrMutable): Point {
  return Point.create({
    x: p.x + offset.x,
    y: p.y + offset.y,
  });
}

function transformPoint(
  p: Point.OrMutable,
  translate: Point.OrMutable,
  scale: number,
  rotate: number,
): Point {
  let result = scalePoint(p, scale);
  result = rotatePoint(result, rotate);
  result = translatePoint(result, translate);
  return result;
}

/**
 * Calculate metrics for a shape
 */
function calculateShapeMetrics(
  shape: Shape,
  unit: MeasurementUnit,
): ShapeMetrics {
  const shapeUnion = shape.union;
  let area = 0;
  let perimeter = 0;
  let points: Point.OrMutable[] = [];

  if (shapeUnion.kind === "triangle") {
    const vertices = shapeUnion.value.vertices;
    if (vertices.length !== 3) {
      throw new Error("Triangle must have exactly 3 vertices");
    }
    const a = distance(vertices[0], vertices[1]);
    const b = distance(vertices[1], vertices[2]);
    const c = distance(vertices[2], vertices[0]);
    area = calculateTriangleArea(a, b, c);
    perimeter = a + b + c;
    points = [...vertices];
  } else if (shapeUnion.kind === "circle") {
    const { center, radius } = shapeUnion.value;
    area = Math.PI * radius * radius;
    perimeter = 2 * Math.PI * radius;
    points = [center];
  } else if (shapeUnion.kind === "rectangle") {
    const { topLeft, width, height } = shapeUnion.value;
    area = width * height;
    perimeter = 2 * (width + height);
    points = [
      topLeft,
      Point.create({ x: topLeft.x + width, y: topLeft.y }),
      Point.create({ x: topLeft.x + width, y: topLeft.y + height }),
      Point.create({ x: topLeft.x, y: topLeft.y + height }),
    ];
  } else if (shapeUnion.kind === "polygon") {
    const vertices = shapeUnion.value.vertices;
    area = calculatePolygonArea(vertices);
    for (let i = 0; i < vertices.length; i++) {
      const j = (i + 1) % vertices.length;
      perimeter += distance(vertices[i], vertices[j]);
    }
    points = [...vertices];
  }

  return ShapeMetrics.create({
    area: convertArea(area, unit),
    perimeter: convertDistance(perimeter, unit),
    centroid: calculateCentroid(points),
    boundingBox: calculateBoundingBox(points),
  });
}

// =============================================================================
// SERVICE IMPLEMENTATION
// =============================================================================

class GeometryService {
  async calculateMetrics(
    req: CalculateMetricsRequest,
  ): Promise<CalculateMetricsResponse> {
    const metrics = calculateShapeMetrics(req.shape, req.unit);
    return CalculateMetricsResponse.create({
      metrics,
      calculatedAt: $.Timestamp.now(),
    });
  }

  async analyzeTriangle(
    req: AnalyzeTriangleRequest,
  ): Promise<AnalyzeTriangleResponse> {
    const { vertexA, vertexB, vertexC } = req;

    const sideA = distance(vertexA, vertexB);
    const sideB = distance(vertexB, vertexC);
    const sideC = distance(vertexC, vertexA);

    const epsilon = 0.0001;

    // Check validity
    if (
      sideA + sideB <= sideC ||
      sideB + sideC <= sideA ||
      sideC + sideA <= sideB
    ) {
      throw new Error("Invalid triangle: points are collinear");
    }

    const isEquilateral =
      Math.abs(sideA - sideB) < epsilon && Math.abs(sideB - sideC) < epsilon;

    const isIsosceles =
      isEquilateral ||
      Math.abs(sideA - sideB) < epsilon ||
      Math.abs(sideB - sideC) < epsilon ||
      Math.abs(sideC - sideA) < epsilon;

    const isRightTri = isRightTriangle(sideA, sideB, sideC);

    const info = TriangleInfo.create({
      sideA,
      sideB,
      sideC,
      isEquilateral,
      isIsosceles,
      isRightTriangle: isRightTri,
    });

    const shape = Shape.create({
      kind: "triangle",
      value: { vertices: [vertexA, vertexB, vertexC] },
    });

    const metrics = calculateShapeMetrics(shape, MeasurementUnit.METERS);

    return AnalyzeTriangleResponse.create({
      info,
      metrics,
      analyzedAt: $.Timestamp.now(),
    });
  }

  async batchAnalyze(req: BatchAnalyzeRequest): Promise<BatchAnalyzeResponse> {
    const results: ShapeAnalysisResult[] = [];
    let totalArea = 0;

    for (const drawableShape of req.shapes) {
      try {
        const metrics = calculateShapeMetrics(drawableShape.geometry, req.unit);
        results.push(
          ShapeAnalysisResult.create({
            shapeId: drawableShape.id,
            metrics,
            error: null,
          }),
        );
        totalArea += metrics.area;
      } catch (err) {
        results.push(
          ShapeAnalysisResult.create({
            shapeId: drawableShape.id,
            metrics: ShapeMetrics.create<"partial">({}),
            error: err instanceof Error ? err.message : String(err),
          }),
        );
      }
    }

    return BatchAnalyzeResponse.create({
      results,
      completedAt: $.Timestamp.now(),
      totalArea,
      shapeCount: req.shapes.length,
    });
  }

  async transformShape(
    req: TransformShapeRequest,
  ): Promise<TransformShapeResponse> {
    const { shape, translate, scale, rotateRadians } = req;

    const originalMetrics = calculateShapeMetrics(
      shape,
      MeasurementUnit.METERS,
    );

    const shapeUnion = shape.union;
    let transformed: Shape;

    if (shapeUnion.kind === "triangle") {
      const vertices = shapeUnion.value.vertices;
      const newVertices = vertices.map((v) =>
        transformPoint(v, translate, scale, rotateRadians),
      );
      transformed = Shape.create({
        kind: "triangle",
        value: { vertices: newVertices },
      });
    } else if (shapeUnion.kind === "circle") {
      const { center, radius } = shapeUnion.value;
      const newCenter = transformPoint(center, translate, scale, rotateRadians);
      transformed = Shape.create({
        kind: "circle",
        value: { center: newCenter, radius: radius * scale },
      });
    } else if (shapeUnion.kind === "rectangle") {
      const { topLeft, width, height } = shapeUnion.value;
      const newTopLeft = transformPoint(
        topLeft,
        translate,
        scale,
        rotateRadians,
      );
      transformed = Shape.create({
        kind: "rectangle",
        value: {
          topLeft: newTopLeft,
          width: width * scale,
          height: height * scale,
        },
      });
    } else if (shapeUnion.kind === "polygon") {
      // polygon
      const vertices = shapeUnion.value.vertices;
      const newVertices = vertices.map((v) =>
        transformPoint(v, translate, scale, rotateRadians),
      );
      transformed = Shape.create({
        kind: "polygon",
        value: { vertices: newVertices },
      });
    } else {
      throw new Error(`Unknown shape type: ${shapeUnion.kind}`);
    }

    const transformedMetrics = calculateShapeMetrics(
      transformed,
      MeasurementUnit.METERS,
    );

    return TransformShapeResponse.create({
      transformed,
      originalMetrics,
      transformedMetrics,
      transformedAt: $.Timestamp.now(),
    });
  }

  async findLargestShape(
    req: FindLargestShapeRequest,
  ): Promise<FindLargestShapeResponse> {
    const { collection, criterion, unit } = req;

    if (collection.shapes.length === 0) {
      throw new Error("Collection is empty");
    }

    const criterionUnion = criterion.union;
    const useArea = criterionUnion.kind === "AREA";

    let largestShape: DrawableShape | null = null;
    let largestValue = -1;
    let largestMetrics: ShapeMetrics | null = null;

    const ranked: Array<{ shapeId: string; value: number }> = [];

    for (const drawableShape of collection.shapes) {
      const metrics = calculateShapeMetrics(drawableShape.geometry, unit);
      const value = useArea ? metrics.area : metrics.perimeter;

      ranked.push({ shapeId: drawableShape.id, value });

      if (value > largestValue) {
        largestValue = value;
        largestShape = drawableShape;
        largestMetrics = metrics;
      }
    }

    if (!largestShape || !largestMetrics) {
      throw new Error("No valid shapes found");
    }

    // Sort by value descending
    ranked.sort((a, b) => b.value - a.value);

    return FindLargestShapeResponse.create({
      largestShape,
      metrics: largestMetrics,
      rankedShapes: ranked,
    });
  }
}

const geometryService = new GeometryService();

installServiceOnExpressApp(
  app,
  "/geometry",
  new Service({})
    .addMethod(
      CalculateMetrics,
      GeometryService.prototype.calculateMetrics.bind(geometryService),
    )
    .addMethod(
      AnalyzeTriangle,
      GeometryService.prototype.analyzeTriangle.bind(geometryService),
    )
    .addMethod(
      BatchAnalyze,
      GeometryService.prototype.batchAnalyze.bind(geometryService),
    )
    .addMethod(
      TransformShape,
      GeometryService.prototype.transformShape.bind(geometryService),
    )
    .addMethod(
      FindLargestShape,
      GeometryService.prototype.findLargestShape.bind(geometryService),
    ),
  express.text,
  express.json,
);

app.listen(port, () => {
  console.log(`Geometry service is running on http://localhost:${port}/`);
  console.log(`Service endpoint: http://localhost:${port}/geometry`);
  open(`http://localhost:${port}/geometry?studio`);
});
