import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import rehypeSanitize from 'rehype-sanitize'

interface Props {
  content: string
  className?: string
}

export function MarkdownMessage({ content, className }: Props) {
  return (
    <div className={className ? `markdown-body ${className}` : 'markdown-body'}>
      <ReactMarkdown remarkPlugins={[remarkGfm]} rehypePlugins={[rehypeSanitize]}>
        {content}
      </ReactMarkdown>
    </div>
  )
}
