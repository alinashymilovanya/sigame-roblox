export type Media = {
    kind: string,
    path: string,
    assetId: string?,
}

export type Question = {
    id: string,
    text: string,
    answer: string,
    value: number,
    category: string,
    media: { Media },
    answered: boolean,
}

export type Pack = {
    id: string,
    title: string,
    formatVersion: string,
    categories: { string },
    questions: { Question },
}

return {}

