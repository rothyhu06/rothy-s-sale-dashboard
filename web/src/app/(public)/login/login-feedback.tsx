const feedbackByCode = {
  missing_credentials: "请输入邮箱和密码。",
  invalid_credentials: "邮箱或密码不正确。",
} as const;

type LoginFeedbackProps = {
  error?: string | string[];
};

export function LoginFeedback({ error }: LoginFeedbackProps) {
  if (typeof error !== "string" || !(error in feedbackByCode)) {
    return null;
  }

  const message = feedbackByCode[error as keyof typeof feedbackByCode];
  return <p className="type-body-sm mt-5 text-danger" role="alert">{message}</p>;
}
