import JiraClient from "jira-client";

/**
 * GitHub Comment를 Jira Comment로 동기화하는 스크립트
 */

// 환경 변수 검증
function validateEnv() {
  const required = [
    "JIRA_HOST",
    "JIRA_EMAIL",
    "JIRA_API_TOKEN",
    "JIRA_PROJECT_KEY",
    "GITHUB_EVENT_ACTION",
    "GITHUB_COMMENT_ID",
    "GITHUB_COMMENT_BODY",
    "GITHUB_COMMENT_USER",
    "GITHUB_ISSUE_NUMBER",
    "GITHUB_ISSUE_TITLE",
    "GITHUB_REPOSITORY_NAME",
  ];

  const missing = required.filter((key) => !process.env[key]);

  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missing.join(", ")}`
    );
  }
}

// Jira 클라이언트 초기화
function initJiraClient() {
  return new JiraClient({
    protocol: "https",
    host: process.env.JIRA_HOST,
    username: process.env.JIRA_EMAIL,
    password: process.env.JIRA_API_TOKEN,
    apiVersion: "2",
    strictSSL: true,
  });
}

// GitHub Issue 제목에서 Jira Key 추출
function extractJiraKeyFromTitle(title) {
  const match = title.match(/\[([A-Z]+-\d+)\]/);
  return match ? match[1] : null;
}

// GitHub Comment에서 Jira Comment 본문 생성
function buildJiraCommentBody() {
  const commentId = process.env.GITHUB_COMMENT_ID;
  const commentBody = process.env.GITHUB_COMMENT_BODY;
  const commentUser = process.env.GITHUB_COMMENT_USER;
  const commentUserUrl = process.env.GITHUB_COMMENT_USER_URL;
  const commentUrl = process.env.GITHUB_COMMENT_HTML_URL;

  // Jira Comment ID 마커 (편집 시 찾기 위함)
  const marker = `{panel:borderStyle=none|bgColor=#f4f5f7}GitHub Comment ID: ${commentId}{panel}`;

  // 본문 구성
  let body = `${marker}\n\n`;
  body += `*작성자:* [${commentUser}|${commentUserUrl}]\n`;
  body += `*GitHub:* [View Comment|${commentUrl}]\n\n`;
  body += `{quote}${commentBody}{quote}`;

  return body;
}

// Jira Comment 검색 (GitHub Comment ID로)
async function findJiraCommentByGithubId(jira, issueKey, githubCommentId) {
  try {
    const comments = await jira.getComments(issueKey);

    if (!comments || !comments.comments) {
      return null;
    }

    // GitHub Comment ID 마커가 포함된 코멘트 찾기
    const marker = `GitHub Comment ID: ${githubCommentId}`;
    const jiraComment = comments.comments.find(
      (c) => c.body && c.body.includes(marker)
    );

    return jiraComment || null;
  } catch (error) {
    console.error("Jira 코멘트 검색 실패:", error.message);
    return null;
  }
}

// GitHub Comment 생성 처리
async function handleCommentCreated(jira, jiraKey) {
  console.log("=== GitHub 코멘트 생성 - Jira에 코멘트 추가 ===");

  const commentBody = buildJiraCommentBody();

  try {
    await jira.addComment(jiraKey, commentBody);
    console.log(`✅ Jira 코멘트 추가 성공: ${jiraKey}`);
  } catch (error) {
    console.error("❌ Jira 코멘트 추가 실패:", error.message);
    throw error;
  }
}

// GitHub Comment 편집 처리
async function handleCommentEdited(jira, jiraKey) {
  console.log("=== GitHub 코멘트 편집 - Jira 코멘트 업데이트 ===");

  const githubCommentId = process.env.GITHUB_COMMENT_ID;

  // 기존 Jira 코멘트 찾기
  const existingComment = await findJiraCommentByGithubId(
    jira,
    jiraKey,
    githubCommentId
  );

  if (!existingComment) {
    console.log(
      "⚠️  기존 Jira 코멘트를 찾을 수 없습니다. 새 코멘트를 추가합니다."
    );
    await handleCommentCreated(jira, jiraKey);
    return;
  }

  console.log(`찾은 Jira 코멘트 ID: ${existingComment.id}`);

  const commentBody = buildJiraCommentBody();

  try {
    await jira.updateComment(jiraKey, existingComment.id, commentBody);
    console.log(`✅ Jira 코멘트 업데이트 성공: ${jiraKey}`);
  } catch (error) {
    console.error("❌ Jira 코멘트 업데이트 실패:", error.message);
    throw error;
  }
}

// 메인 실행
async function main() {
  try {
    console.log("🚀 GitHub Comment to Jira 동기화 시작");
    console.log("Event Action:", process.env.GITHUB_EVENT_ACTION);
    console.log("Comment ID:", process.env.GITHUB_COMMENT_ID);
    console.log("Issue Number:", process.env.GITHUB_ISSUE_NUMBER);
    console.log("Issue Title:", process.env.GITHUB_ISSUE_TITLE);

    // 환경 변수 검증
    validateEnv();

    // GitHub Issue 제목에서 Jira Key 추출
    const jiraKey = extractJiraKeyFromTitle(process.env.GITHUB_ISSUE_TITLE);

    if (!jiraKey) {
      console.log(
        "⚠️  Issue 제목에서 Jira Key를 찾을 수 없습니다. 동기화를 건너뜁니다."
      );
      console.log("Note: Jira Key는 '[JST-123]' 형식으로 제목에 포함되어야 합니다.");
      process.exit(0);
    }

    console.log(`추출된 Jira Key: ${jiraKey}`);

    // Jira 클라이언트 초기화
    const jira = initJiraClient();

    // 이벤트 타입별 처리
    switch (process.env.GITHUB_EVENT_ACTION) {
      case "created":
        await handleCommentCreated(jira, jiraKey);
        break;

      case "edited":
        await handleCommentEdited(jira, jiraKey);
        break;

      default:
        console.log(
          `⚠️  처리되지 않는 이벤트: ${process.env.GITHUB_EVENT_ACTION}`
        );
    }

    console.log("✅ Comment 동기화 완료");
    process.exit(0);
  } catch (error) {
    console.error("❌ Comment 동기화 실패:", error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// 스크립트 실행
main();
