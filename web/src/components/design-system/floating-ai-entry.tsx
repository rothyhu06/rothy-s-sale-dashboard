import { Button } from "./button";

export function FloatingAiEntry({ onOpen }: { onOpen: () => void }) {
  return (
    <Button className="fixed bottom-6 right-6 z-30 min-h-11 max-md:bottom-20" onClick={onOpen} size="large" variant="primary">
      Ask Your Editor
    </Button>
  );
}
