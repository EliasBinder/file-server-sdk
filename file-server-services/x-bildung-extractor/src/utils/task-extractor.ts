import { sendMQMessage } from "./mq";

export type TOperation = {
  type: "pdf_metadata_extractor";
  inputFile: string;
  outputFile: string;
  onMissingOrInvalidMetadata?: "fail" | "ignore";
};

export type TRequest = {
  pipeline: any; // The entire pipeline structure, can be typed more specifically if needed
  stepId: string;
  task: TOperation;
};

export const extractTask = (msg: TRequest) => {
  return [
    msg.task,
    {
      pipeline: msg.pipeline,
      stepId: msg.stepId,
    },
  ] as const;
};

export const publishTaskCompletion = (msg: TRequest) => {
  sendMQMessage(
    { queue: "orchestrator" },
    {
      pipeline: msg.pipeline,
      stepId: msg.stepId,
    },
  );
};
