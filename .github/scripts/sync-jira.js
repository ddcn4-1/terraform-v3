import JiraClient from "jira-client";
import fs from "fs";

/**
 * GitHub Actions용 Jira 동기화 스크립트
 * 환경 변수를 통해 GitHub 이벤트 정보를 받아 Jira와 동기화
 */

// 환경 변수 검증
function validateEnv() {
  const required = [
    "JIRA_HOST",
    "JIRA_EMAIL",
    "JIRA_API_TOKEN",
    "JIRA_PROJECT_KEY",
    "GITHUB_EVENT_ACTION",
    "GITHUB_ISSUE_NUMBER",
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

// GitHub 라벨에서 우선순위 결정
function determinePriority(labelsJson) {
  try {
    const labels = JSON.parse(labelsJson || "[]");
    const labelNames = labels.map((l) => l.name.toLowerCase());

    if (labelNames.some((l) => ["critical", "urgent"].includes(l))) {
      return "Highest";
    }
    if (labelNames.some((l) => ["high", "important"].includes(l))) {
      return "High";
    }
    if (labelNames.includes("low")) {
      return "Low";
    }

    return process.env.JIRA_DEFAULT_PRIORITY || "Medium";
  } catch (error) {
    console.log("라벨 파싱 실패, 기본 우선순위 사용:", error.message);
    return process.env.JIRA_DEFAULT_PRIORITY || "Medium";
  }
}

// GitHub 라벨을 Jira 라벨로 변환
function convertLabels(labelsJson) {
  try {
    const labels = JSON.parse(labelsJson || "[]");
    return labels.map((l) => l.name.toLowerCase().replace(/\s+/g, "-"));
  } catch (error) {
    console.log("라벨 변환 실패:", error.message);
    return [];
  }
}

const ISSUE_TYPE_SYNONYMS = {
  Epic: ["Epic", "에픽"],
  Task: ["Task", "작업"],
};

// 이슈 타입 매핑 (GitHub 라벨 → Jira 이슈 타입)
function mapIssueTypeToJira(githubType) {
  // 기본적으로 영문 사용
  const englishMapping = {
    Epic: "Epic",
    Task: "Task",
    Subtask: "Subtask",
  };

  // 한글 프로젝트용
  const koreanMapping = {
    Epic: "에픽",
    Task: "작업",
    Subtask: "하위 작업",
  };

  const useKorean = process.env.JIRA_USE_KOREAN_ISSUE_TYPES === "true";
  const mapping = useKorean ? koreanMapping : englishMapping;

  return mapping[githubType] || githubType;
}

function normalizeIssueTypeName(name) {
  return (name || "").trim().toLowerCase();
}

function isEpicTypeName(name) {
  const normalized = normalizeIssueTypeName(name);
  return ISSUE_TYPE_SYNONYMS.Epic.some(
    (alias) => normalizeIssueTypeName(alias) === normalized
  );
}

function isTaskTypeName(name) {
  const normalized = normalizeIssueTypeName(name);
  return ISSUE_TYPE_SYNONYMS.Task.some(
    (alias) => normalizeIssueTypeName(alias) === normalized
  );
}

function resolveIssueTypeName(preferredName, availableTypes = []) {
  if (!preferredName) {
    return preferredName;
  }

  const normalizedPreferred = normalizeIssueTypeName(preferredName);

  const exactMatch = availableTypes.find(
    (type) => normalizeIssueTypeName(type.name) === normalizedPreferred
  );
  if (exactMatch) {
    return exactMatch.name;
  }

  const synonyms = isEpicTypeName(preferredName)
    ? ISSUE_TYPE_SYNONYMS.Epic
    : isTaskTypeName(preferredName)
    ? ISSUE_TYPE_SYNONYMS.Task
    : [preferredName];

  for (const synonym of synonyms) {
    const match = availableTypes.find(
      (type) =>
        normalizeIssueTypeName(type.name) === normalizeIssueTypeName(synonym)
    );
    if (match) {
      return match.name;
    }
  }

  return preferredName;
}

// GitHub 이슈 본문에서 Epic Link 파싱
function parseEpicLinkFromBody(issueBody) {
  if (!issueBody) {
    return null;
  }

  // Epic Link 패턴 매칭
  const patterns = [
    // ### Epic Link\nJST-123
    /###\s*Epic\s*Link\s*\n+([A-Z]+-\d+)/i,
    // **Epic Link:** JST-123
    /\*\*Epic\s*Link:\*\*\s*([A-Z]+-\d+)/i,
    // Epic Link: JST-123
    /Epic\s*Link:\s*([A-Z]+-\d+)/i,
    // GitHub issue reference: #45
    /###\s*Epic\s*Link\s*\n+#(\d+)/i,
  ];

  for (const pattern of patterns) {
    const match = issueBody.match(pattern);
    if (match && match[1]) {
      const epicRef = match[1].trim();
      console.log(`✓ Epic Link 파싱 성공: "${epicRef}"`);
      return epicRef;
    }
  }

  console.log("✗ Epic Link를 찾을 수 없음");
  return null;
}

// GitHub 이슈 제목/본문에서 Jira Key 추출 ([JST-123] 형식)
function extractJiraKeyFromText(text) {
  if (!text) {
    return null;
  }

  const match = text.match(/\[([A-Z][A-Z0-9_-]+-\d+)\]/i);
  if (match && match[1]) {
    const key = match[1].toUpperCase();
    console.log(`✓ 텍스트에서 Jira Key 추출: ${key}`);
    return key;
  }

  return null;
}

// Jira JQL 검색 (POST /rest/api/3/search/jql)
async function searchJiraIssues(jql, { maxResults = 50 } = {}) {
  const host = process.env.JIRA_HOST;
  const email = process.env.JIRA_EMAIL;
  const token = process.env.JIRA_API_TOKEN;

  if (!host || !email || !token) {
    throw new Error(
      "Jira 인증 정보(JIRA_HOST, JIRA_EMAIL, JIRA_API_TOKEN)가 필요합니다."
    );
  }

  const baseUrl = host.startsWith("http")
    ? host.replace(/\/$/, "")
    : `https://${host}`.replace(/\/$/, "");
  const url = `${baseUrl}/rest/api/3/search/jql`;

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        Authorization: `Basic ${Buffer.from(`${email}:${token}`).toString(
          "base64"
        )}`,
      },
      body: JSON.stringify({
        query: jql,
        startAt: 0,
        maxResults,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(
        `Jira JQL 검색 실패 (${response.status} ${response.statusText}): ${errorText}`
      );
    }

    const data = await response.json();
    return data;
  } catch (error) {
    console.error("Jira JQL search API 호출 중 오류:", error.message);
    throw error;
  }
}

// GitHub issue 번호를 Jira Epic Key로 변환
async function resolveGitHubIssueToEpic(jira, githubIssueNumber, repoName) {
  try {
    const epicType = mapIssueTypeToJira("Epic");
    const jql = `project = ${process.env.JIRA_PROJECT_KEY} AND labels = "repo:${repoName}" AND summary ~ "GitHub #${githubIssueNumber}" AND issuetype = "${epicType}"`;

    console.log(`GitHub #${githubIssueNumber}를 Epic으로 검색 중...`);
    console.log("JQL:", jql);

    const result = await searchJiraIssues(jql, { maxResults: 1 });

    if (result.issues && result.issues.length > 0) {
      const epicKey = result.issues[0].key;
      console.log(`✓ GitHub #${githubIssueNumber} → Jira Epic: ${epicKey}`);
      return epicKey;
    }

    console.log(
      `✗ GitHub #${githubIssueNumber}에 해당하는 Epic을 찾을 수 없음`
    );
    return null;
  } catch (error) {
    console.error(`Epic 검색 실패:`, error.message);
    return null;
  }
}

// Jira Epic 존재 여부 확인
async function validateEpicExists(jira, epicKey) {
  try {
    console.log(`Epic ${epicKey} 존재 여부 확인 중...`);
    const issue = await jira.getIssue(epicKey);

    // Epic 타입인지 확인 (영문/한글 모두 허용)
    const epicType = mapIssueTypeToJira("Epic");
    const isEpic =
      issue.fields.issuetype.name === epicType ||
      issue.fields.issuetype.name === "Epic" ||
      issue.fields.issuetype.name === "에픽";

    if (!isEpic) {
      console.log(
        `✗ ${epicKey}는 Epic이 아닙니다 (타입: ${issue.fields.issuetype.name})`
      );
      return false;
    }

    console.log(`✓ Epic ${epicKey} 존재 확인 (${issue.fields.summary})`);
    return true;
  } catch (error) {
    console.error(`✗ Epic ${epicKey} 확인 실패:`, error.message);
    return false;
  }
}

// Task를 Epic에 연결 (이슈 생성 후 호출)
// Jira Cloud REST API v3 사용: parent 필드로 직접 연결 (권장 방식)
async function linkTaskToEpic(jira, taskKey, epicKey) {
  try {
    console.log(`\n=== Task ${taskKey}를 Epic ${epicKey}에 연결 시작 ===`);

    // 방법 1: parent 필드 사용 (Jira Cloud 권장 방식)
    // PUT /rest/api/3/issue/{issueIdOrKey}
    try {
      const updateData = {
        fields: {
          parent: {
            key: epicKey,
          },
        },
      };

      await jira.updateIssue(taskKey, updateData);
      console.log(
        `✅ Task ${taskKey}가 parent 필드를 통해 Epic ${epicKey}에 연결되었습니다`
      );
      console.log("=== Epic 연결 완료 (parent 필드 사용) ===\n");
      return true;
    } catch (parentError) {
      console.log(
        `⚠️  parent 필드 연결 실패, Epic Link 필드로 재시도: ${parentError.message}`
      );

      // 방법 2: Epic Link 커스텀 필드 사용 (레거시 방식, fallback)
      const fields = await jira.listFields();
      const epicLinkField = fields.find(
        (f) =>
          f.name === "Epic Link" ||
          f.id === process.env.JIRA_EPIC_LINK_FIELD ||
          f.id === "customfield_10014" // 일반적인 Epic Link 필드 ID
      );

      if (!epicLinkField) {
        console.error("✗ Epic Link 필드를 찾을 수 없습니다");
        console.error("✗ parent 필드와 Epic Link 필드 모두 사용 불가");
        return false;
      }

      console.log(
        `✓ Epic Link 필드 발견: ${epicLinkField.name} (${epicLinkField.id})`
      );

      // Epic Link 커스텀 필드로 연결
      const epicLinkUpdateData = {
        fields: {
          [epicLinkField.id]: epicKey,
        },
      };

      await jira.updateIssue(taskKey, epicLinkUpdateData);
      console.log(
        `✅ Task ${taskKey}가 Epic Link 필드를 통해 Epic ${epicKey}에 연결되었습니다`
      );
      console.log("=== Epic 연결 완료 (Epic Link 필드 사용) ===\n");
      return true;
    }
  } catch (error) {
    console.error(`❌ Epic 연결 실패:`, error.message);
    if (error.response) {
      console.error(
        "응답 데이터:",
        JSON.stringify(error.response.data, null, 2)
      );
    }
    return false;
  }
}

// Parent 이슈 처리
async function processParentIssue(jira, issueType, issueBody, repoName) {
  // Task 타입이 아니면 Epic Link 설정 불가
  if (!isTaskTypeName(issueType)) {
    return null;
  }

  // GitHub 부모 이슈 정보 (환경 변수)
  let parentIssueNumber = process.env.GITHUB_PARENT_ISSUE_NUMBER;
  const parentIssueTitle = process.env.GITHUB_PARENT_ISSUE_TITLE || "";

  // JSON 문자열 따옴표 제거 (예: "8" → 8)
  if (parentIssueNumber && typeof parentIssueNumber === "string") {
    parentIssueNumber = parentIssueNumber.replace(/^["']|["']$/g, "").trim();
  }

  let epicRef = null;

  // 1순위: 부모 이슈 제목에 포함된 Jira Key ([KEY-123] Title)
  if (parentIssueTitle) {
    const keyFromTitle = extractJiraKeyFromText(parentIssueTitle);
    if (keyFromTitle) {
      epicRef = keyFromTitle;
      console.log(`✓ 부모 이슈 제목에서 Jira Epic Key 감지: ${epicRef}`);
    }
  }

  // 2순위: GitHub 부모 이슈 번호 (Epic GitHub Issue → Jira Epic)
  if (!epicRef && parentIssueNumber && parentIssueNumber !== "") {
    console.log(`✓ GitHub 부모 이슈 발견: #${parentIssueNumber}`);
    epicRef = parentIssueNumber;
  }

  if (!epicRef) {
    // 3순위: 이슈 본문에서 Epic Link 파싱 (수동 입력)
    epicRef = parseEpicLinkFromBody(issueBody);
    if (!epicRef) {
      return null;
    }
  }

  let epicKey = epicRef;

  // GitHub issue 번호 형식(숫자만)이면 Jira Epic Key로 변환
  if (/^\d+$/.test(epicRef)) {
    epicKey = await resolveGitHubIssueToEpic(jira, epicRef, repoName);
    if (!epicKey) {
      console.log(
        `⚠️  GitHub #${epicRef}에 해당하는 Epic을 찾을 수 없어 Epic Link를 설정하지 않습니다.`
      );
      return null;
    }
  }

  // Epic 존재 여부 확인
  const epicExists = await validateEpicExists(jira, epicKey);
  if (!epicExists) {
    console.log(
      `⚠️  Epic ${epicKey}가 존재하지 않거나 접근할 수 없어 Parent를 설정하지 않습니다.`
    );
    return null;
  }

  return { parentKey: epicKey };
}

// GitHub 이슈에서 이슈 타입 결정 (라벨 기반)
function determineIssueType(labelsJson) {
  try {
    const labels = JSON.parse(labelsJson || "[]");
    const labelNames = labels.map((l) => l.name.toLowerCase());

    if (labelNames.includes("epic") || labelNames.includes("type:epic")) {
      const epicType = mapIssueTypeToJira("Epic");
      console.log(`라벨에서 Epic 타입 감지 → Jira: "${epicType}"`);
      return epicType;
    }

    const taskAliases = [
      "task",
      "type:task",
      "refactor",
      "docs",
      "doc",
      "documentation",
      "chore",
      "bug",
      "fix",
    ];

    if (taskAliases.some((alias) => labelNames.includes(alias))) {
      const taskType = mapIssueTypeToJira("Task");
      console.log(
        `라벨에서 Task 계열(${taskAliases.join(
          ", "
        )}) 감지 → Jira: "${taskType}"`
      );
      return taskType;
    }

    const taskType = mapIssueTypeToJira("Task");
    console.log(`기본 타입 사용: ${taskType} (Task)`);
    return taskType;
  } catch (error) {
    console.log("이슈 타입 결정 실패, 기본 타입 사용:", error.message);
    return mapIssueTypeToJira("Task");
  }
}

// Jira 이슈 설명 생성
function buildDescription() {
  const assigneesJson = process.env.GITHUB_ISSUE_ASSIGNEES || "[]";
  let assignees = [];

  try {
    assignees = JSON.parse(assigneesJson).map((a) => a.login);
  } catch (error) {
    console.log("담당자 파싱 실패:", error.message);
  }

  const sections = [];

  // GitHub Issue body 추가 (있는 경우)
  let issueBody = process.env.GITHUB_ISSUE_BODY || '';
  if (issueBody.trim()) {
    // GitHub 마크다운 헤더를 Jira Wiki Markup 헤더로 변환
    issueBody = issueBody
      .replace(/^### (.+)$/gm, 'h3. $1')  // ### → h3.
      .replace(/^## (.+)$/gm, 'h2. $1')   // ## → h2.
      .replace(/^# (.+)$/gm, 'h1. $1');   // # → h1.

    // "No response"를 "-"로 대체
    issueBody = issueBody.replace(/No response/gi, '-');

    sections.push(issueBody.trim());
    sections.push(""); // 구분선
    sections.push("---");
    sections.push(""); // 구분선
  }

  // GitHub 메타데이터
  sections.push(`*GitHub Issue:* [#${process.env.GITHUB_ISSUE_NUMBER}|${process.env.GITHUB_ISSUE_URL}]`);
  sections.push(`*Repository:* [${process.env.GITHUB_REPOSITORY_FULL_NAME}|${process.env.GITHUB_REPOSITORY_URL}]`);
  sections.push(`*Created by:* [${process.env.GITHUB_ISSUE_USER}|${process.env.GITHUB_ISSUE_USER_URL}]`);

  if (assignees.length > 0) {
    sections.push("");
    sections.push(`*GitHub Assignees:* ${assignees.join(", ")}`);
  }

  return sections.join("\n");
}

// GitHub Issue 제목에서 Jira 키 추출
function extractJiraKeyFromTitle(title) {
  const match = title.match(/^\[([A-Z]+-\d+)\]/);
  return match ? match[1] : null;
}

// Jira에서 GitHub 이슈 번호로 검색
async function findJiraIssueByGitHub(jira, githubIssueNumber, repoName) {
  try {
    // 1. GitHub Issue 제목에서 Jira 키 추출 시도
    const issueTitle = process.env.GITHUB_ISSUE_TITLE || '';
    const jiraKey = extractJiraKeyFromTitle(issueTitle);

    if (jiraKey) {
      console.log(`✓ GitHub Issue 제목에서 Jira 키 추출: ${jiraKey}`);

      try {
        const issue = await jira.findIssue(jiraKey);
        console.log(`✓ Jira 이슈 발견: ${issue.key}`);
        return issue;
      } catch (error) {
        console.log(`⚠️  Jira 키 ${jiraKey}로 이슈를 찾을 수 없음:`, error.message);
        // Jira 키로 찾을 수 없으면 아래의 JQL 검색으로 fallback
      }
    }

    // 2. Fallback: JQL 검색 (구버전 호환성)
    console.log("Jira 키를 찾을 수 없어 JQL 검색을 시도합니다...");
    const jql = `project = ${process.env.JIRA_PROJECT_KEY} AND labels = "repo:${repoName}" AND summary ~ "GitHub #${githubIssueNumber}"`;
    console.log("Jira 검색 JQL:", jql);

    const result = await searchJiraIssues(jql, { maxResults: 1 });

    return result.issues && result.issues.length > 0 ? result.issues[0] : null;
  } catch (error) {
    console.error("Jira 검색 실패:", error.message);
    return null;
  }
}

// 프로젝트에서 사용 가능한 이슈 타입 조회
async function getAvailableIssueTypes(jira) {
  try {
    const project = await jira.getProject(process.env.JIRA_PROJECT_KEY);
    console.log("\n=== 사용 가능한 Jira 이슈 타입 ===");

    if (project.issueTypes) {
      project.issueTypes.forEach((type) => {
        console.log(`  - ${type.name} (id: ${type.id})`);
      });
    }

    return project.issueTypes || [];
  } catch (error) {
    console.error("⚠️  이슈 타입 조회 실패:", error.message);
    return [];
  }
}

// 새 이슈 생성 (opened)
async function handleIssueOpened(jira) {
  console.log("=== 새 Jira 이슈 생성 ===");

  // 디버깅: 이슈 본문 로그
  console.log("\n--- GitHub 이슈 본문 (처음 500자) ---");
  const bodyPreview = (process.env.GITHUB_ISSUE_BODY || "").substring(0, 500);
  console.log(bodyPreview);
  console.log("--- 본문 끝 ---\n");

  // 사용 가능한 이슈 타입 조회
  const availableTypes = await getAvailableIssueTypes(jira);

  const priority = determinePriority(process.env.GITHUB_ISSUE_LABELS);
  const requestedIssueType = determineIssueType(process.env.GITHUB_ISSUE_LABELS);
  const issueType = resolveIssueTypeName(requestedIssueType, availableTypes);
  const description = buildDescription();

  if (issueType !== requestedIssueType) {
    console.log(
      `\n✓ 최종 감지된 이슈 타입: ${issueType} (요청: ${requestedIssueType})`
    );
  } else {
    console.log(`\n✓ 최종 감지된 이슈 타입: ${issueType}`);
  }

  const issueData = {
    fields: {
      project: {
        key: process.env.JIRA_PROJECT_KEY,
      },
      summary: `${process.env.GITHUB_ISSUE_TITLE}`,
      description,
      issuetype: {
        name: issueType,
      },
    },
  };

  // Assignee는 설정하지 않음 (비워둠)
  console.log("✓ Assignee를 비워둡니다 (수동 할당 필요)");

  // 에픽이 아닌 경우에만 priority 설정 (에픽은 priority가 없음)
  if (!isEpicTypeName(issueType)) {
    issueData.fields.priority = {
      name: priority,
    };
  }

  // Parent Epic 확인 (이슈 생성 후 parent 필드로 연결)
  console.log("\n=== Parent Epic 확인 시작 ===");
  const parentResult = await processParentIssue(
    jira,
    issueType,
    process.env.GITHUB_ISSUE_BODY,
    process.env.GITHUB_REPOSITORY_NAME
  );

  if (parentResult) {
    console.log(
      `✓ Parent Epic 확인: ${parentResult.parentKey} (생성 후 parent 필드로 연결 예정)`
    );
  } else {
    console.log("Parent Epic 없음 - Task를 독립 이슈로 생성");
  }
  console.log("=== Parent Epic 확인 완료 ===\n");

  console.log("생성할 이슈 데이터:", JSON.stringify(issueData, null, 2));

  try {
    const result = await jira.addNewIssue(issueData);
    const issueTypeName = isEpicTypeName(issueType) ? "Epic" : "태스크";
    console.log(`✅ Jira ${issueTypeName} 생성 성공: ${result.key}`);

    // Parent Epic에 연결 (Task인 경우만)
    if (parentResult) {
      if (isTaskTypeName(issueType)) {
        console.log(`\n=== Parent 필드로 Epic 연결 시작 ===`);
        const linked = await linkTaskToEpic(
          jira,
          result.key,
          parentResult.parentKey
        );
        if (!linked) {
          console.log("⚠️  Epic 연결에 실패했지만 이슈는 생성되었습니다");
        }
      }
    }

    // 결과를 파일로 저장 (GitHub Actions 코멘트용)
    const resultData = {
      success: true,
      jiraKey: result.key,
      issueType: issueType,
    };

    if (parentResult) {
      resultData.parentKey = parentResult.parentKey;
    }

    fs.writeFileSync("jira-result.json", JSON.stringify(resultData), "utf8");

    return result;
  } catch (error) {
    console.error("❌ Jira 이슈 생성 실패:", error.message);
    if (error.response) {
      console.error(
        "응답 데이터:",
        JSON.stringify(error.response.data, null, 2)
      );
    }
    throw error;
  }
}

// 이슈 수정 (edited)
async function handleIssueEdited(jira) {
  console.log("=== Jira 태스크 업데이트 ===");

  const jiraIssue = await findJiraIssueByGitHub(
    jira,
    process.env.GITHUB_ISSUE_NUMBER,
    process.env.GITHUB_REPOSITORY_NAME
  );

  if (!jiraIssue) {
    console.log("⚠️  대응하는 Jira 이슈를 찾을 수 없습니다.");
    return;
  }

  console.log(`찾은 Jira 이슈: ${jiraIssue.key}`);

  const issueType = jiraIssue.fields.issuetype.name;

  // GitHub 제목에서 Jira 키 제거하여 순수 제목만 추출
  let cleanTitle = process.env.GITHUB_ISSUE_TITLE;
  const jiraKeyInTitle = cleanTitle.match(/^\[([A-Z]+-\d+)\]\s*/);
  if (jiraKeyInTitle) {
    cleanTitle = cleanTitle.replace(/^\[([A-Z]+-\d+)\]\s*/, '');
  }

  // GitHub Issue body를 포함한 description 생성
  const description = buildDescription();

  const updateData = {
    fields: {
      summary: cleanTitle,
      description: description,
    },
  };

  // Parent Epic 연결 처리 (Task 타입인 경우만)
  if (isTaskTypeName(issueType)) {
    console.log("\n=== Epic 연결 업데이트 확인 ===");
    const parentResult = await processParentIssue(
      jira,
      issueType,
      process.env.GITHUB_ISSUE_BODY,
      process.env.GITHUB_REPOSITORY_NAME
    );

    if (parentResult) {
      console.log(`✓ Epic 업데이트 시도: ${parentResult.parentKey}`);
      const linked = await linkTaskToEpic(
        jira,
        jiraIssue.key,
        parentResult.parentKey
      );
      if (!linked) {
        console.log("⚠️  Epic 연결 업데이트 실패");
      }
    } else {
      console.log("✓ Epic 연결 없음 또는 제거됨");
    }
    console.log("=== Epic 연결 업데이트 완료 ===\n");
  }

  try {
    await jira.updateIssue(jiraIssue.key, updateData);

    console.log(`✅ Jira 태스크 업데이트 성공: ${jiraIssue.key}`);

    // GitHub Projects 상태에 따라 Jira 상태 전환
    const projectStatus = process.env.GITHUB_PROJECT_STATUS;
    if (projectStatus) {
      console.log(`\n=== GitHub Projects 상태 동기화 ===`);
      console.log(`Projects Status: ${projectStatus}`);

      let jiraTransition = null;

      // GitHub Projects 상태 → Jira 상태 매핑
      switch (projectStatus) {
        case "Todo":
          jiraTransition = process.env.JIRA_TODO_TRANSITION_NAME || "To Do";
          break;
        case "In Progress":
          jiraTransition =
            process.env.JIRA_IN_PROGRESS_TRANSITION_NAME || "In Progress";
          break;
        case "Done":
          jiraTransition = process.env.JIRA_DONE_TRANSITION_NAME || "Done";
          break;
        default:
          console.log(`⚠️  매핑되지 않은 상태: ${projectStatus}`);
      }

      if (jiraTransition) {
        const transitioned = await transitionJiraIssue(
          jira,
          jiraIssue.key,
          jiraTransition
        );
        if (transitioned) {
          console.log(`✅ Jira 상태 동기화 성공: ${jiraTransition}`);
        } else {
          console.log(`⚠️  Jira 상태 전환 실패: ${jiraTransition}`);
        }
      }

      console.log("=== Projects 상태 동기화 완료 ===\n");
    }
  } catch (error) {
    console.error("❌ Jira 태스크 업데이트 실패:", error.message);
    throw error;
  }
}

// Jira 이슈 상태 전환 헬퍼 함수
async function transitionJiraIssue(jira, issueKey, targetStatusName) {
  try {
    // 1. 사용 가능한 전환(transition) 목록 조회
    const transitions = await jira.listTransitions(issueKey);
    console.log(`사용 가능한 전환: ${transitions.transitions.map((t) => t.name).join(", ")}`);

    // 2. 목표 상태로 전환할 수 있는 transition 찾기
    const targetTransition = transitions.transitions.find(
      (t) => t.name === targetStatusName || t.to.name === targetStatusName
    );

    if (!targetTransition) {
      console.log(
        `⚠️  '${targetStatusName}' 전환을 찾을 수 없습니다. 사용 가능한 전환: ${transitions.transitions.map((t) => t.name).join(", ")}`
      );
      return false;
    }

    // 3. 전환 실행
    await jira.transitionIssue(issueKey, {
      transition: {
        id: targetTransition.id,
      },
    });

    console.log(`✅ Jira 상태 전환 성공: ${targetTransition.to.name}`);
    return true;
  } catch (error) {
    console.error(`❌ Jira 상태 전환 실패:`, error.message);
    return false;
  }
}

// 이슈 닫기 (closed)
async function handleIssueClosed(jira) {
  console.log("=== GitHub 이슈 닫힘 - Jira 상태 전환 ===");

  const jiraIssue = await findJiraIssueByGitHub(
    jira,
    process.env.GITHUB_ISSUE_NUMBER,
    process.env.GITHUB_REPOSITORY_NAME
  );

  if (!jiraIssue) {
    console.log("⚠️  대응하는 Jira 이슈를 찾을 수 없습니다.");
    return;
  }

  console.log(`찾은 Jira 이슈: ${jiraIssue.key}`);
  console.log(`현재 Jira 상태: ${jiraIssue.fields.status.name}`);

  // Jira 상태를 "Done"으로 전환
  const doneStatusName = process.env.JIRA_DONE_TRANSITION_NAME || "Done";
  const transitioned = await transitionJiraIssue(
    jira,
    jiraIssue.key,
    doneStatusName
  );

  try {
    // 코멘트 추가
    await jira.addComment(
      jiraIssue.key,
      `GitHub 이슈 [#${process.env.GITHUB_ISSUE_NUMBER}|${process.env.GITHUB_ISSUE_URL}]가 닫혔습니다.${transitioned ? `\n상태가 '${doneStatusName}'(으)로 변경되었습니다.` : ""}`
    );

    console.log(`✅ Jira 코멘트 추가 성공: ${jiraIssue.key}`);
  } catch (error) {
    console.error("❌ Jira 코멘트 추가 실패:", error.message);
    throw error;
  }
}

// 이슈 재오픈 (reopened)
async function handleIssueReopened(jira) {
  console.log("=== GitHub 이슈 재오픈 - Jira 상태 전환 ===");

  const jiraIssue = await findJiraIssueByGitHub(
    jira,
    process.env.GITHUB_ISSUE_NUMBER,
    process.env.GITHUB_REPOSITORY_NAME
  );

  if (!jiraIssue) {
    console.log("⚠️  대응하는 Jira 이슈를 찾을 수 없습니다.");
    return;
  }

  console.log(`찾은 Jira 이슈: ${jiraIssue.key}`);
  console.log(`현재 Jira 상태: ${jiraIssue.fields.status.name}`);

  // Jira 상태를 "To Do" 또는 "In Progress"로 전환
  const todoStatusName =
    process.env.JIRA_TODO_TRANSITION_NAME ||
    process.env.JIRA_IN_PROGRESS_TRANSITION_NAME ||
    "To Do";
  const transitioned = await transitionJiraIssue(
    jira,
    jiraIssue.key,
    todoStatusName
  );

  try {
    // 코멘트 추가
    await jira.addComment(
      jiraIssue.key,
      `GitHub 이슈 [#${process.env.GITHUB_ISSUE_NUMBER}|${process.env.GITHUB_ISSUE_URL}]가 재오픈되었습니다.${transitioned ? `\n상태가 '${todoStatusName}'(으)로 변경되었습니다.` : ""}`
    );

    console.log(`✅ Jira 코멘트 추가 성공: ${jiraIssue.key}`);
  } catch (error) {
    console.error("❌ Jira 코멘트 추가 실패:", error.message);
    throw error;
  }
}

// 라벨 변경 (labeled/unlabeled)
async function handleLabelChanged(jira) {
  console.log("=== GitHub 라벨 변경 - Jira Priority 업데이트 ===");
  console.log(`Action: ${process.env.GITHUB_EVENT_ACTION}`);

  const jiraIssue = await findJiraIssueByGitHub(
    jira,
    process.env.GITHUB_ISSUE_NUMBER,
    process.env.GITHUB_REPOSITORY_NAME
  );

  if (!jiraIssue) {
    console.log("⚠️  대응하는 Jira 이슈를 찾을 수 없습니다.");
    return;
  }

  console.log(`찾은 Jira 이슈: ${jiraIssue.key}`);

  // 현재 GitHub 이슈의 모든 라벨로 Priority 재계산
  const newPriority = determinePriority(process.env.GITHUB_ISSUE_LABELS);
  console.log(`새로운 Priority: ${newPriority}`);

  // 현재 Jira 이슈의 Priority 확인
  const currentPriority = jiraIssue.fields.priority?.name;
  console.log(`현재 Jira Priority: ${currentPriority || "없음"}`);

  if (currentPriority === newPriority) {
    console.log("✓ Priority 변경 없음 - 업데이트 생략");
    return;
  }

  try {
    await jira.updateIssue(jiraIssue.key, {
      fields: {
        priority: { name: newPriority },
      },
    });

    console.log(
      `✅ Jira Priority 업데이트 성공: ${currentPriority || "없음"} → ${newPriority}`
    );

    // 변경 내용 코멘트 추가
    await jira.addComment(
      jiraIssue.key,
      `GitHub 라벨 변경으로 인해 Priority가 업데이트되었습니다: ${currentPriority || "없음"} → ${newPriority}\n관련 GitHub 이슈: [#${process.env.GITHUB_ISSUE_NUMBER}|${process.env.GITHUB_ISSUE_URL}]`
    );
  } catch (error) {
    console.error("❌ Jira Priority 업데이트 실패:", error.message);
    throw error;
  }
}

// 메인 실행
async function main() {
  try {
    console.log("🚀 Jira 동기화 시작");
    console.log("Event Action:", process.env.GITHUB_EVENT_ACTION);
    console.log("Issue Number:", process.env.GITHUB_ISSUE_NUMBER);
    console.log("Repository:", process.env.GITHUB_REPOSITORY_FULL_NAME);

    // 환경 변수 검증
    validateEnv();

    // Jira 클라이언트 초기화
    const jira = initJiraClient();

    // 이벤트 타입별 처리
    switch (process.env.GITHUB_EVENT_ACTION) {
      case "opened":
        await handleIssueOpened(jira);
        break;

      case "edited":
        await handleIssueEdited(jira);
        break;

      case "closed":
        await handleIssueClosed(jira);
        break;

      case "reopened":
        await handleIssueReopened(jira);
        break;

      case "labeled":
      case "unlabeled":
        await handleLabelChanged(jira);
        break;

      default:
        console.log(
          `⚠️  처리되지 않는 이벤트: ${process.env.GITHUB_EVENT_ACTION}`
        );
    }

    console.log("✅ Jira 동기화 완료");
    process.exit(0);
  } catch (error) {
    console.error("❌ Jira 동기화 실패:", error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// 스크립트 실행
main();
