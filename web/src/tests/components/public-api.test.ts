import { describe, expect, it } from "vitest";
import {
  Button,
  Badge,
  Card,
  Checkbox,
  CommandDialog,
  ContextPanel,
  ContextPanelSheet,
  Divider,
  EmptyState,
  FloatingAiEntry,
  InputField,
  Navigation,
  Progress,
  SectionHeader,
  SelectInput,
  Skeleton,
  TextArea,
  TextInput,
  Timeline,
} from "@/components/design-system";

describe("design system public API", () => {
  it("exports the complete frozen component surface", () => {
    for (const component of [Button, Badge, Card, Checkbox, CommandDialog, ContextPanel, ContextPanelSheet, Divider, EmptyState, FloatingAiEntry, InputField, Navigation, Progress, SectionHeader, SelectInput, Skeleton, TextArea, TextInput, Timeline]) {
      expect(component).toBeTruthy();
      expect(["function", "object"]).toContain(typeof component);
    }
  });
});
