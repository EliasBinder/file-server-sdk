import amqp from "amqplib";

let channel: amqp.Channel;

export const connectMQ = async (
  queue: string,
  onMessage: (msg: any) => Promise<void>,
) => {
  if (!process.env.RABBIT_MQ_URI) {
    throw new Error("RABBIT_MQ_URI environment variable is not set");
  }

  let connection: amqp.ChannelModel;
  try {
    connection = await amqp.connect(process.env.RABBIT_MQ_URI);
  } catch (error) {
    console.error("MQ connection failed. Retrying in 2 seconds...", error);
    setTimeout(() => {
      connectMQ(queue, onMessage);
    }, 2000);
    return;
  }

  connection.on("close", () => {
    console.error("MQ connection closed. Reconnecting in 2 seconds...");
    setTimeout(() => {
      connectMQ(queue, onMessage);
    }, 2000);
  });
  connection.on("error", (err) => {
    console.error("MQ connection error. Reconnecting in 2 seconds...", err);
    setTimeout(() => {
      connectMQ(queue, onMessage);
    }, 2000);
  });

  channel = await connection.createChannel();

  await channel.assertQueue(queue, { durable: true });
  console.log(`Connected to MQ and asserted queue: ${queue}`);

  channel.consume(queue, (msg) => {
    if (msg) {
      try {
        const content = msg.content.toString();
        const payload = JSON.parse(content);
        onMessage(payload);
        channel.ack(msg);
      } catch (err) {
        console.error("Error processing MQ message:", err);
        channel.nack(msg, false, false); // Reject message without requeueing
      }
    }
  });
};

export type MQReceiver = {
  exchange?: string;
  queue?: string;
};

export const sendMQMessage = (
  receiver: MQReceiver,
  payload: any,
  options?: {
    routingKey?: string;
  },
) => {
  const msg = JSON.stringify(payload);
  if (receiver.queue) {
    channel!.sendToQueue(receiver.queue, Buffer.from(msg));
  } else if (receiver.exchange) {
    channel!.publish(
      receiver.exchange,
      options?.routingKey || "",
      Buffer.from(msg),
    );
  } else {
    throw new Error(
      "Invalid MQ receiver: must specify either queue or exchange",
    );
  }
};

export const reportErrorToMQ = (
  error: Error,
  context: {
    pipeline: any;
    stepId: string;
  },
) => {
  const errorMessage = {
    message: error.message,
    pipeline: context.pipeline,
    stepId: context.stepId,
    timestamp: new Date().toISOString(),
    service: "pdf_merger",
  };
  sendMQMessage({ queue: "errors" }, errorMessage);
  return error;
};
